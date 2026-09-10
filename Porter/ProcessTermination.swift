import Foundation
import Darwin

protocol ProcessTerminating: Sendable {
    func terminate(_ entry: ActivePort) async throws
}

struct LiveProcessTerminator: ProcessTerminating {
    var control: any ProcessControl = SystemProcessControl()
    var exitTimeout: Duration = .seconds(3)

    func terminate(_ entry: ActivePort) async throws {
        if entry.owner == .sharedDocker { throw ProcessTerminationError.sharedOwner }
        if case .database(let engine) = entry.owner { throw ProcessTerminationError.databaseOwner(engine) }
        guard let identity = entry.processIdentity, identity.pid == entry.pid, entry.pid > 1 else {
            throw ProcessTerminationError.unverified
        }

        // Check the listener, then inspect the kernel identity immediately before signaling.
        guard try await control.isListening(pid: entry.pid, port: entry.port) else {
            throw ProcessTerminationError.noLongerListening
        }
        guard let current = try control.snapshot(pid: entry.pid), current.identity == identity else {
            throw ProcessTerminationError.processChanged
        }
        switch LivePortScanner.owner(processName: current.name) {
        case .sharedDocker: throw ProcessTerminationError.sharedOwner
        case .database(let engine): throw ProcessTerminationError.databaseOwner(engine)
        case .server: break
        }
        if current.hasExited { return }
        try control.sendTermination(pid: entry.pid)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: exitTimeout)
        while true {
            try Task.checkCancellation()
            guard let snapshot = try control.snapshot(pid: entry.pid) else { return }
            if snapshot.identity != identity || snapshot.hasExited { return }
            guard clock.now < deadline else { throw ProcessTerminationError.stillRunning }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}

protocol ProcessControl: Sendable {
    func snapshot(pid: Int32) throws -> ProcessSnapshot?
    func isListening(pid: Int32, port: UInt16) async throws -> Bool
    func sendTermination(pid: Int32) throws
}

struct SystemProcessControl: ProcessControl {
    func snapshot(pid: Int32) throws -> ProcessSnapshot? {
        try ProcessSnapshot.read(pid: pid)
    }

    func isListening(pid: Int32, port: UInt16) async throws -> Bool {
        do {
            let output = try await LivePortScanner().runShell(
                "/usr/sbin/lsof", args: ["-a", "-p", String(pid), "-iTCP:\(port)",
                                         "-sTCP:LISTEN", "-n", "-P"], timeout: 3
            )
            return LivePortScanner.parseLsofOutput(output).contains { $0.pid == pid && $0.port == port }
        } catch {
            throw ProcessTerminationError.listenerVerificationFailed
        }
    }

    func sendTermination(pid: Int32) throws {
        guard Darwin.kill(pid, SIGTERM) == 0 else {
            let code = errno
            throw ProcessTerminationError.signalFailed(code)
        }
    }
}

enum ProcessTerminationError: Error, LocalizedError, Equatable {
    case sharedOwner
    case databaseOwner(DatabaseEngine)
    case unverified
    case processChanged
    case noLongerListening
    case listenerVerificationFailed
    case signalFailed(Int32)
    case stillRunning

    var errorDescription: String? {
        switch self {
        case .sharedOwner:
            return "Manage this port in Docker; its process is shared by other containers."
        case .databaseOwner(let engine):
            return "Manage \(engine.displayName) with its database tools; this is not a web server."
        case .unverified:
            return "The server process could not be verified. Refresh and try again."
        case .processChanged:
            return "The server process changed. Refresh and try again."
        case .noLongerListening:
            return "This process is no longer listening on the selected port. Refresh and try again."
        case .listenerVerificationFailed:
            return "Could not verify the selected port. Refresh and try again."
        case .signalFailed(let code):
            return "Could not stop the server: \(String(cString: strerror(code)))."
        case .stillRunning:
            return "The server is still running after the stop request. Stop it from its terminal or app."
        }
    }
}
