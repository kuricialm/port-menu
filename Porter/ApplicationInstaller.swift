import AppKit
import Security

/// Keeps a usable previous installation until the replacement has opened.
@MainActor
struct ApplicationInstaller {
    var copy: (URL, URL) throws -> Void = FileManager.default.copyItem(at:to:)
    var move: (URL, URL) throws -> Void = FileManager.default.moveItem(at:to:)
    var remove: (URL) throws -> Void = FileManager.default.removeItem(at:)
    var exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    var validate: @MainActor (URL, URL) throws -> Void = validateCopy
    var launch: @MainActor (URL) async throws -> Void = launchApplication

    /// Returns a retained backup path only if post-launch cleanup failed.
    /// The source bundle is intentionally never removed.
    func install(from source: URL, to destination: URL) async throws -> URL? {
        guard source.resolvingSymlinksInPath().path != destination.resolvingSymlinksInPath().path else {
            throw InstallationError.invalidSource
        }
        let sourceAccess = source.startAccessingSecurityScopedResource()
        let destinationAccess = destination.startAccessingSecurityScopedResource()
        defer {
            if sourceAccess { source.stopAccessingSecurityScopedResource() }
            if destinationAccess { destination.stopAccessingSecurityScopedResource() }
        }
        let parent = destination.deletingLastPathComponent()
        let stem = destination.deletingPathExtension().lastPathComponent
        let stage = parent.appending(path: "\(stem).install-\(UUID().uuidString).app")
        let backup = parent.appending(path: "\(stem).backup-\(UUID().uuidString).app")
        var hasBackup = false
        var installedReplacement = false

        defer { if exists(stage) { try? remove(stage) } }

        do {
            // Complete all potentially lengthy copying and validation while the
            // existing installation remains at its original path.
            try copy(source, stage)
            try validate(source, stage)
            if exists(destination) {
                try move(destination, backup)
                hasBackup = true
            }
            try move(stage, destination)
            installedReplacement = true
            try await launch(destination)
        } catch {
            let installError = error
            do {
                if installedReplacement {
                    try move(destination, stage)
                }
                if hasBackup {
                    try move(backup, destination)
                }
            } catch {
                // Never erase the previous copy when restoration itself fails.
                throw InstallationError.recoveryFailed(
                    installError: installError.localizedDescription,
                    recoveryError: error.localizedDescription,
                    backup: hasBackup ? backup : nil
                )
            }
            throw installError
        }

        if hasBackup {
            do { try remove(backup) }
            catch { return backup }
        }
        return nil
    }

    private static func validateCopy(source: URL, staged: URL) throws {
        guard let original = Bundle(url: source), let copied = Bundle(url: staged),
              let identifier = original.bundleIdentifier,
              copied.bundleIdentifier == identifier,
              copied.object(forInfoDictionaryKey: "CFBundleVersion") as? String == original.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              copied.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == original.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let executable = copied.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw InstallationError.invalidSource
        }
        var code: SecStaticCode?
        let creationStatus = SecStaticCodeCreateWithPath(staged as CFURL, [], &code)
        guard creationStatus == errSecSuccess, let code else {
            throw InstallationError.invalidSignature(creationStatus)
        }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures)
        let status = SecStaticCodeCheckValidity(code, flags, nil)
        guard status == errSecSuccess else { throw InstallationError.invalidSignature(status) }
    }

    private static func launchApplication(at url: URL) async throws {
        let handoff = try InstallationHandoff.create(destination: url, parentPID: ProcessInfo.processInfo.processIdentifier)
        defer { handoff.cleanUp() }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = handoff.launchArguments
        // A replacement must launch its new executable, rather than re-open
        // the still-running source. It stays hidden until the source exits.
        configuration.createsNewApplicationInstance = true
        let application = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while !handoff.isAcknowledged(by: application.processIdentifier) {
            guard !application.isTerminated, ContinuousClock.now < deadline else {
                // Only this install's newly launched copy is stopped. A failed
                // handshake must not become active after rollback.
                application.terminate()
                throw InstallationError.launchFailed
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard !application.isTerminated else { throw InstallationError.launchFailed }
    }
}

private enum InstallationError: LocalizedError {
    case invalidSource
    case invalidSignature(OSStatus)
    case launchFailed
    case recoveryFailed(installError: String, recoveryError: String, backup: URL?)

    var errorDescription: String? {
        switch self {
        case .invalidSource:
            return "The copied application could not be validated. The existing installation was not replaced."
        case .invalidSignature(let status):
            let reason = SecCopyErrorMessageString(status, nil) as String? ?? "Code signature validation failed (\(status))."
            return "The copied application did not pass its signature check. \(reason)"
        case .launchFailed:
            return "The installed application exited before it could be opened."
        case .recoveryFailed(let installError, let recoveryError, let backup):
            var message = "\(installError)\n\nThe previous installation could not be restored: \(recoveryError)"
            if let backup { message += "\n\nYour previous copy is preserved at \(backup.path)." }
            return message
        }
    }
}
