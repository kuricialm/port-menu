import Foundation
import Testing
@testable import Port_Menu

struct ProcessRunnerTests {
    @Test func drainsLargeStdoutAndStderrWithoutBackpressure() async throws {
        let output = try await ProcessRunner.run("/usr/bin/ruby", arguments: ["-e", """
        64.times do
          STDERR.write('e' * 16384)
          STDOUT.write('o' * 16384)
        end
        """], timeout: 5)
        #expect(output.utf8.count == 1_048_576)
        #expect(output.allSatisfy { $0 == "o" })
    }

    @Test func retainsBoundedUsefulErrorTail() async throws {
        do {
            _ = try await ProcessRunner.run("/usr/bin/ruby", arguments: ["-e", """
            STDERR.write('e' * 512000)
            STDERR.write('final diagnostic')
            exit 7
            """], timeout: 5)
            Issue.record("Expected command failure")
        } catch ProcessRunnerError.failed(let message) {
            #expect(message.contains("exited with 7"))
            #expect(message.hasSuffix("final diagnostic"))
            #expect(message.utf8.count < 66_000)
        }
    }

    @Test func deadlineCompletesWhenChildIgnoresSIGTERM() async throws {
        let start = ContinuousClock.now
        do {
            _ = try await ProcessRunner.run("/usr/bin/ruby", arguments: ["-e", "trap('TERM') {}; sleep 5"], timeout: 0.25)
            Issue.record("Expected command timeout")
        } catch ProcessRunnerError.timedOut {
            #expect(start.duration(to: .now) < .seconds(2))
        }
    }

    @Test func cancellationCompletesWithoutWaitingForCommandDeadline() async throws {
        let task = Task {
            try await ProcessRunner.run("/bin/sleep", arguments: ["10"], timeout: 20)
        }
        try await Task.sleep(for: .milliseconds(50))
        let start = ContinuousClock.now
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(start.duration(to: .now) < .seconds(2))
        }
    }

    @Test func rejectsUnboundedStdoutInsteadOfReturningTruncatedData() async throws {
        do {
            _ = try await ProcessRunner.run("/usr/bin/ruby", arguments: ["-e", "STDOUT.write('x' * (17 * 1024 * 1024))"], timeout: 5)
            Issue.record("Expected output limit failure")
        } catch ProcessRunnerError.outputTooLarge {}
    }

    @Test func reportsLaunchFailure() async throws {
        do {
            _ = try await ProcessRunner.run("/does-not-exist-port-menu", arguments: [], timeout: 1)
            Issue.record("Expected launch failure")
        } catch ProcessRunnerError.failed(let message) {
            #expect(message.contains("does-not-exist-port-menu"))
        }
    }
}
