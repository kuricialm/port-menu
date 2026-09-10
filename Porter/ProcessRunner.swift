import Foundation
import Darwin

/// Owns and reaps its children itself. Signals and waitpid run on one worker, so
/// a completed child's PID can never be reused between an exit check and a signal.
struct ProcessRunner {
    static func run(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval,
        environment: [String: String]? = nil
    ) async throws -> String {
        let cancellation = ProcessCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    do {
                        let output = try execute(executable, arguments: arguments, timeout: timeout,
                                                 environment: environment, cancellation: cancellation)
                        continuation.resume(returning: output)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    private static func execute(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval,
        environment: [String: String]?,
        cancellation: ProcessCancellation
    ) throws -> String {
        if cancellation.isCancelled { throw CancellationError() }
        let deadline = ProcessInfo.processInfo.systemUptime + max(0, timeout)
        let stdout = try makePipe()
        defer { close(stdout.read); close(stdout.write) }
        let stderr = try makePipe()
        defer { close(stderr.read); close(stderr.write) }

        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0 else {
            throw ProcessRunnerError.failed("Could not initialize command output.")
        }
        defer { posix_spawn_file_actions_destroy(&actions) }
        guard posix_spawnattr_init(&attributes) == 0 else {
            throw ProcessRunnerError.failed("Could not initialize command attributes.")
        }
        defer { posix_spawnattr_destroy(&attributes) }

        // A private process group permits cancellation of the command's children
        // too, without touching any existing server or simulator process group.
        let setupResults = [
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP)),
            posix_spawnattr_setpgroup(&attributes, 0),
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0),
            posix_spawn_file_actions_adddup2(&actions, stdout.write, STDOUT_FILENO),
            posix_spawn_file_actions_adddup2(&actions, stderr.write, STDERR_FILENO),
            posix_spawn_file_actions_addclose(&actions, stdout.read),
            posix_spawn_file_actions_addclose(&actions, stderr.read),
            posix_spawn_file_actions_addclose(&actions, stdout.write),
            posix_spawn_file_actions_addclose(&actions, stderr.write)
        ]
        guard setupResults.allSatisfy({ $0 == 0 }) else {
            throw ProcessRunnerError.failed("Could not configure command output.")
        }

        var child: pid_t = 0
        var combinedEnvironment = ProcessInfo.processInfo.environment
        if let environment { combinedEnvironment.merge(environment) { _, new in new } }
        let result = withCStringArray([executable] + arguments) { argv in
            withCStringArray(combinedEnvironment.map { "\($0.key)=\($0.value)" }) { envp in
                posix_spawn(&child, executable, &actions, &attributes, argv, envp)
            }
        }
        guard result == 0 else {
            throw ProcessRunnerError.failed("\(URL(filePath: executable).lastPathComponent): \(String(cString: strerror(result)))")
        }

        var output = CommandOutput(limit: 16 * 1_024 * 1_024, retainTail: false)
        var errors = CommandOutput(limit: 64 * 1_024, retainTail: true)
        var status: Int32 = 0
        var failure: Error?
        var forceKillAt: TimeInterval?

        while true {
            drain(stdout.read, into: &output)
            drain(stderr.read, into: &errors)

            let now = ProcessInfo.processInfo.systemUptime
            if failure == nil {
                if cancellation.isCancelled { failure = CancellationError() }
                else if now >= deadline { failure = ProcessRunnerError.timedOut }
                else if output.truncated { failure = ProcessRunnerError.outputTooLarge }
                if failure != nil {
                    // No other code can reap this child before our final signal.
                    _ = Darwin.kill(-child, SIGTERM)
                    forceKillAt = now + 0.15
                }
            }

            if failure == nil {
                let waited = waitpid(child, &status, WNOHANG)
                if waited == child {
                    // Drain bytes already in the pipes; do not wait for descendants
                    // that might have inherited an output descriptor to close it.
                    drain(stdout.read, into: &output)
                    drain(stderr.read, into: &errors)
                    break
                }
                if waited == -1 && errno != EINTR {
                    throw ProcessRunnerError.failed("Could not observe command completion.")
                }
            }
            if let forceKillAt, now >= forceKillAt {
                // Keep the group leader unreaped during the grace period, even
                // if TERM already stopped it: its reserved PID protects this
                // final group signal from reuse, and catches stubborn descendants.
                _ = Darwin.kill(-child, SIGKILL)
                // Reaping is detached only after the final signal. Even an
                // uninterruptible child cannot hold up the caller's deadline.
                let childToReap = child
                DispatchQueue.global(qos: .utility).async {
                    var finalStatus: Int32 = 0
                    while waitpid(childToReap, &finalStatus, 0) == -1 && errno == EINTR {}
                }
                throw failure ?? ProcessRunnerError.timedOut
            }

            var descriptors = [pollfd(fd: stdout.read, events: Int16(POLLIN), revents: 0),
                               pollfd(fd: stderr.read, events: Int16(POLLIN), revents: 0)]
            _ = poll(&descriptors, nfds_t(descriptors.count), 20)
        }

        if let failure { throw failure }
        if output.truncated { throw ProcessRunnerError.outputTooLarge }
        guard status == 0 else {
            let detail = String(decoding: errors.data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let name = URL(filePath: executable).lastPathComponent
            let exitDescription = status & 0x7f == 0 ? "exited with \((status >> 8) & 0xff)" : "was terminated"
            let suffix = detail.isEmpty ? "" : ": \(errors.truncated ? "…" : "")\(detail)"
            throw ProcessRunnerError.failed("\(name) \(exitDescription)\(suffix)")
        }
        return String(decoding: output.data, as: UTF8.self)
    }

    private static func makePipe() throws -> (read: Int32, write: Int32) {
        var descriptors: [Int32] = [0, 0]
        guard pipe(&descriptors) == 0 else {
            throw ProcessRunnerError.failed("Could not create command output pipes.")
        }
        guard fcntl(descriptors[0], F_SETFD, FD_CLOEXEC) != -1,
              fcntl(descriptors[1], F_SETFD, FD_CLOEXEC) != -1,
              fcntl(descriptors[0], F_SETFL, O_NONBLOCK) != -1 else {
            close(descriptors[0]); close(descriptors[1])
            throw ProcessRunnerError.failed("Could not configure command output pipes.")
        }
        return (descriptors[0], descriptors[1])
    }

    private static func drain(_ descriptor: Int32, into output: inout CommandOutput) {
        var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
        // Bound each drain pass so a continuously writing child cannot starve
        // deadline/cancellation checks or the other stream.
        for _ in 0..<16 {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count > 0 { output.append(buffer.prefix(count)) }
            else if count == -1 && errno == EINTR { continue }
            else { return }
        }
    }

    private static func withCStringArray<T>(_ strings: [String], body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> T) -> T {
        var pointers = strings.map { strdup($0) } + [nil]
        defer { pointers.forEach { free($0) } }
        return pointers.withUnsafeMutableBufferPointer { body($0.baseAddress!) }
    }
}

enum ProcessRunnerError: Error, LocalizedError {
    case timedOut
    case outputTooLarge
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .timedOut: "The command timed out."
        case .outputTooLarge: "The command produced too much output."
        case .failed(let message): message
        }
    }
}

private final class ProcessCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }
}

private struct CommandOutput {
    var limit: Int
    var retainTail: Bool
    var data = Data()
    var truncated = false

    mutating func append(_ bytes: ArraySlice<UInt8>) {
        if data.count + bytes.count > limit { truncated = true }
        if retainTail {
            data.append(contentsOf: bytes)
            if data.count > limit { data.removeFirst(data.count - limit) }
        } else if data.count < limit {
            data.append(contentsOf: bytes.prefix(limit - data.count))
        }
    }
}
