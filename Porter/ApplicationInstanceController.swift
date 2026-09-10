import AppKit
import Darwin
import Observation

@MainActor
@Observable
final class ApplicationInstanceController {
    static let shared = ApplicationInstanceController()

    var isPrimaryInstance = false
    private var didStart = false
    private let instanceLock = ApplicationInstanceLock()

    static var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    func start(onReady: @escaping @MainActor () -> Void) {
        guard !didStart else { return }
        didStart = true
        guard !Self.isTestHost else {
            isPrimaryInstance = true
            return
        }

        let current = NSRunningApplication.current
        let identifier = Bundle.main.bundleIdentifier ?? "eduard.Porter"
        do {
            let handoff = try InstallationHandoff.received(
                arguments: ProcessInfo.processInfo.arguments,
                destination: Bundle.main.bundleURL,
                currentPID: current.processIdentifier
            )
            guard let handoff else {
                // SwiftUI persists MenuBarExtra's insertion binding across
                // processes. Reject duplicates before App.init returns, so a
                // hidden duplicate cannot persist visibility=false for the
                // already-running menu. Also insert the primary synchronously.
                guard try claimPrimaryInstance(current: current, identifier: identifier) else {
                    Darwin.exit(EXIT_SUCCESS)
                }
                Task { @MainActor in onReady() }
                return
            }

            // The installer awaits NSWorkspace's launch callback before its
            // source exits. Keep this handshake asynchronous so startup can
            // finish and that callback can run without a parent/child deadlock.
            Task { @MainActor in
                do {
                    guard let source = NSRunningApplication(processIdentifier: handoff.parentPID),
                          source.bundleIdentifier == identifier, !source.isTerminated else {
                        throw InstallationHandoff.HandoffError.invalid
                    }
                    try handoff.acknowledge(pid: current.processIdentifier)
                    let deadline = ContinuousClock.now.advanced(by: .seconds(20))
                    while !source.isTerminated {
                        guard ContinuousClock.now < deadline else { throw InstallationHandoff.HandoffError.invalid }
                        try await Task.sleep(for: .milliseconds(50))
                    }
                    guard try claimPrimaryInstance(current: current, identifier: identifier) else {
                        NSApp.terminate(nil)
                        return
                    }
                    onReady()
                } catch {
                    Log.lifecycle.error("Cannot complete Port Menu installation handoff: \(error.localizedDescription)")
                    NSApp.terminate(nil)
                }
            }
        } catch {
            Log.lifecycle.error("Cannot start Port Menu: \(error.localizedDescription)")
            Darwin.exit(EXIT_FAILURE)
        }
    }

    private func claimPrimaryInstance(current: NSRunningApplication, identifier: String) throws -> Bool {
        // This also catches an older installed release that predates the lock.
        // Only the incoming duplicate exits; an existing app is never stopped.
        if let existing = existingInstance(before: current, identifier: identifier) {
            existing.activate()
            return false
        }
        let directory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: identifier, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard try instanceLock.acquire(at: directory.appending(path: "application.lock")) else {
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                .first { $0.processIdentifier != current.processIdentifier && !$0.isTerminated }?
                .activate()
            return false
        }
        isPrimaryInstance = true
        return true
    }

    private func existingInstance(before current: NSRunningApplication, identifier: String) -> NSRunningApplication? {
        let currentStart = current.launchDate ?? .distantFuture
        return NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { application in
                guard application.processIdentifier != current.processIdentifier, !application.isTerminated else { return false }
                let start = application.launchDate ?? .distantPast
                return start < currentStart || (start == currentStart && application.processIdentifier < current.processIdentifier)
            }
            .min { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
    }
}
