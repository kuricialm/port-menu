import AppKit
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

        Task { @MainActor in
            do {
                let current = NSRunningApplication.current
                let identifier = Bundle.main.bundleIdentifier ?? "eduard.Porter"
                if let handoff = try InstallationHandoff.received(
                    arguments: ProcessInfo.processInfo.arguments,
                    destination: Bundle.main.bundleURL,
                    currentPID: current.processIdentifier
                ) {
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
                }

                // This also catches an older installed release that predates
                // the lock. Normal launches never terminate another app copy.
                if let existing = existingInstance(before: current, identifier: identifier) {
                    existing.activate()
                    NSApp.terminate(nil)
                    return
                }
                let directory = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                    .appending(path: identifier, directoryHint: .isDirectory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                guard try instanceLock.acquire(at: directory.appending(path: "application.lock")) else {
                    NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
                        .first { $0.processIdentifier != current.processIdentifier && !$0.isTerminated }?
                        .activate()
                    NSApp.terminate(nil)
                    return
                }
                isPrimaryInstance = true
                onReady()
            } catch {
                Log.lifecycle.error("Cannot start an additional Port Menu instance: \(error.localizedDescription)")
                NSApp.terminate(nil)
            }
        }
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
