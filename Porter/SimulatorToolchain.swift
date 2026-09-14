import AppKit
import Foundation

/// Simulator commands need a full Xcode installation even when the system's
/// developer directory points at the standalone Command Line Tools.
struct SimulatorToolchain: Equatable, Sendable {
    let developerDirectory: String

    var environment: [String: String] { ["DEVELOPER_DIR": developerDirectory] }

    func run(_ arguments: [String], timeout: TimeInterval) async throws -> String {
        try await ProcessRunner.run("/usr/bin/xcrun", arguments: arguments,
                                    timeout: timeout, environment: environment)
    }

    static func resolve() async throws -> Self {
        // Clear only the child's override to read the actual system selection.
        // Never change xcode-select or the parent process environment.
        let selected = try? await ProcessRunner.run(
            "/usr/bin/xcode-select", arguments: ["-p"], timeout: 5,
            environment: ["DEVELOPER_DIR": ""]
        )
        try Task.checkCancellation()
        let applications = await MainActor.run {
            NSWorkspace.shared.urlsForApplications(withBundleIdentifier: "com.apple.dt.Xcode")
        }
        return try select(
            environmentDirectory: ProcessInfo.processInfo.environment["DEVELOPER_DIR"],
            selectedDirectory: selected,
            installedApplications: applications,
            isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }
        )
    }

    static func select(
        environmentDirectory: String?,
        selectedDirectory: String?,
        installedApplications: [URL],
        isExecutable: (String) -> Bool
    ) throws -> Self {
        let candidates = [environmentDirectory, selectedDirectory].compactMap { $0 }
            + installedApplications.map(\.path).sorted()
        for candidate in candidates {
            let path = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard path.hasPrefix("/") else { continue }
            var directory = URL(filePath: path).standardizedFileURL
            if directory.pathExtension == "app" {
                directory.append(path: "Contents/Developer")
            }
            guard isExecutable(directory.appending(path: "usr/bin/simctl").path) else { continue }
            return Self(developerDirectory: directory.path)
        }
        throw SimulatorToolchainError.missingXcode
    }
}

enum SimulatorToolchainError: Error, LocalizedError {
    case missingXcode

    var errorDescription: String? {
        "Simulator tools were not found. Install a full copy of Xcode to discover simulators."
    }
}
