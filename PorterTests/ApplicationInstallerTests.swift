import Foundation
import Testing
@testable import Port_Menu

@MainActor
struct ApplicationInstallerTests {
    @Test func failedCopyLeavesExistingInstallationAndSourceUntouched() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.copy = { _, stage in
            try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
            throw InstallFixture.Failure.injected
        }

        await #expect(throws: InstallFixture.Failure.self) {
            try await installer.install(from: fixture.source, to: fixture.destination)
        }
        try fixture.expectOriginalCopies()
        #expect(try fixture.temporaryInstallations().isEmpty)
    }

    @Test func invalidSignatureIsRejectedBeforeExistingAppIsMoved() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        // The source is a structurally valid unsigned bundle. Use the production
        // validator so a failed signature never reaches replacement or launch.
        var installer = ApplicationInstaller()
        installer.launch = { _ in Issue.record("An invalid app must never launch") }

        do {
            _ = try await installer.install(from: fixture.source, to: fixture.destination)
            Issue.record("An unsigned app must be rejected")
        } catch {
            #expect(error.localizedDescription.contains("signature"))
        }
        try fixture.expectOriginalCopies()
        #expect(try fixture.temporaryInstallations().isEmpty)
    }

    @Test func failedReplacementRestoresPreviousInstallation() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.move = { source, destination in
            if source.lastPathComponent.contains(".install-") {
                throw InstallFixture.Failure.injected
            }
            try FileManager.default.moveItem(at: source, to: destination)
        }

        await #expect(throws: InstallFixture.Failure.self) {
            try await installer.install(from: fixture.source, to: fixture.destination)
        }
        try fixture.expectOriginalCopies()
        #expect(try fixture.temporaryInstallations().isEmpty)
    }

    @Test func failedLaunchRestoresPreviousInstallation() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.launch = { destination async throws in
            #expect(try fixture.version(at: destination) == "new")
            #expect(try fixture.temporaryInstallations().contains { $0.lastPathComponent.contains(".backup-") })
            throw InstallFixture.Failure.injected
        }

        await #expect(throws: InstallFixture.Failure.self) {
            try await installer.install(from: fixture.source, to: fixture.destination)
        }
        try fixture.expectOriginalCopies()
        #expect(try fixture.temporaryInstallations().isEmpty)
    }

    @Test func failedFirstLaunchRemovesFailedInstallAndKeepsSource() async throws {
        let fixture = try InstallFixture(existingApp: false)
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.launch = { _ in throw InstallFixture.Failure.injected }

        await #expect(throws: InstallFixture.Failure.self) {
            try await installer.install(from: fixture.source, to: fixture.destination)
        }
        #expect(!FileManager.default.fileExists(atPath: fixture.destination.path))
        #expect(try fixture.version(at: fixture.source) == "new")
        #expect(try fixture.temporaryInstallations().isEmpty)
    }

    @Test func successfulLaunchPrecedesBackupCleanupAndKeepsSource() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.launch = { destination async throws in
            #expect(try fixture.version(at: destination) == "new")
            #expect(try fixture.temporaryInstallations().contains { $0.lastPathComponent.contains(".backup-") })
        }

        let retainedBackup = try await installer.install(from: fixture.source, to: fixture.destination)
        #expect(retainedBackup == nil)
        #expect(try fixture.version(at: fixture.destination) == "new")
        #expect(try fixture.version(at: fixture.source) == "new")
        #expect(try fixture.temporaryInstallations().isEmpty)
    }

    @Test func failedRecoveryPreservesBackupAndReportsItsLocation() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.launch = { _ in throw InstallFixture.Failure.injected }
        installer.move = { source, destination in
            if source.lastPathComponent.contains(".backup-") {
                throw InstallFixture.Failure.injected
            }
            try FileManager.default.moveItem(at: source, to: destination)
        }

        do {
            _ = try await installer.install(from: fixture.source, to: fixture.destination)
            Issue.record("Installation should fail")
        } catch {
            let backup = try #require(fixture.temporaryInstallations().first { $0.lastPathComponent.contains(".backup-") })
            #expect(try fixture.version(at: backup) == "old")
            // Directory enumeration may resolve /var to /private/var, while
            // both absolute paths name the same recoverable backup.
            #expect(error.localizedDescription.contains("Applications/\(backup.lastPathComponent)"))
            #expect(try fixture.version(at: fixture.source) == "new")
        }
    }

    @Test func backupCleanupFailureDoesNotUndoSuccessfulLaunch() async throws {
        let fixture = try InstallFixture()
        defer { fixture.cleanUp() }
        var installer = fixture.installer
        installer.remove = { url in
            if url.lastPathComponent.contains(".backup-") { throw InstallFixture.Failure.injected }
            try FileManager.default.removeItem(at: url)
        }

        let backup = try #require(await installer.install(from: fixture.source, to: fixture.destination))
        #expect(try fixture.version(at: backup) == "old")
        #expect(try fixture.version(at: fixture.destination) == "new")
        #expect(try fixture.version(at: fixture.source) == "new")
    }
}

@MainActor
private struct InstallFixture {
    let root: URL
    let source: URL
    let destination: URL

    var installer: ApplicationInstaller {
        ApplicationInstaller(validate: { _, _ in }, launch: { _ in })
    }

    init(existingApp: Bool = true) throws {
        root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appending(path: "PortMenuInstallerTests-\(UUID().uuidString)")
        source = root.appending(path: "Downloads/Port Menu.app")
        destination = root.appending(path: "Applications/Port Menu.app")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try makeApp(at: source, version: "new")
        if existingApp { try makeApp(at: destination, version: "old") }
    }

    func makeApp(at url: URL, version: String) throws {
        let contents = url.appending(path: "Contents")
        let executable = contents.appending(path: "MacOS/PortMenu")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        let metadata: [String: String] = [
            "CFBundleIdentifier": "test.portmenu.installer",
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "PortMenu",
            "CFBundleVersion": version,
            "CFBundleShortVersionString": version,
        ]
        try PropertyListSerialization.data(fromPropertyList: metadata, format: .xml, options: 0)
            .write(to: contents.appending(path: "Info.plist"))
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    }

    func version(at url: URL) throws -> String {
        let data = try Data(contentsOf: url.appending(path: "Contents/Info.plist"))
        let metadata = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        return try #require(metadata?["CFBundleVersion"])
    }

    func expectOriginalCopies() throws {
        #expect(try version(at: source) == "new")
        #expect(try version(at: destination) == "old")
    }

    func temporaryInstallations() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: destination.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains(".install-") || $0.lastPathComponent.contains(".backup-") }
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }

    enum Failure: Error { case injected }
}
