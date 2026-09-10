import Foundation
import Testing
@testable import Port_Menu

struct ApplicationInstanceTests {
    @Test func onlyOneLiveLockOwnerCanProceedAndTheNextCanTakeOver() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "application.lock")
        let running = ApplicationInstanceLock()
        let replacement = ApplicationInstanceLock()

        #expect(try running.acquire(at: url))
        #expect(try !replacement.acquire(at: url))
        running.release()
        #expect(try replacement.acquire(at: url))
        #expect(try !running.acquire(at: url))
    }

    @Test func closingTheOwnerReleasesTheLockWithoutDeletingTheFile() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "application.lock")
        var running: ApplicationInstanceLock? = ApplicationInstanceLock()
        #expect(try running?.acquire(at: url) == true)
        running = nil
        #expect(FileManager.default.fileExists(atPath: url.path))
        let replacement = ApplicationInstanceLock()
        #expect(try replacement.acquire(at: url))
    }

    @Test func symlinksCannotRedirectTheInstanceLock() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appending(path: "unrelated")
        let link = directory.appending(path: "application.lock")
        try Data("preserve".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let instanceLock = ApplicationInstanceLock()
        #expect(throws: (any Error).self) { try instanceLock.acquire(at: link) }
        #expect(try String(contentsOf: target, encoding: .utf8) == "preserve")
    }

    @Test func installAcknowledgementMustComeFromTheLaunchedReplacement() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "Applications/Port Menu.app")
        let handoff = try InstallationHandoff.create(destination: destination, parentPID: 123, root: directory)
        defer { handoff.cleanUp() }
        let received = try #require(try InstallationHandoff.received(
            arguments: ["Port Menu"] + handoff.launchArguments,
            destination: URL(fileURLWithPath: destination.path, isDirectory: true), currentPID: 456
        ))

        #expect(!handoff.isAcknowledged(by: 456))
        try received.acknowledge(pid: 456)
        #expect(handoff.isAcknowledged(by: 456))
        #expect(!handoff.isAcknowledged(by: 789))
        let attributes = try FileManager.default.attributesOfItem(atPath: handoff.directory.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
    }

    @Test func aHandoffCannotBeReusedForAnotherDestinationOrTheSourceProcess() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "Applications/Port Menu.app")
        let handoff = try InstallationHandoff.create(destination: destination, parentPID: 123, root: directory)
        defer { handoff.cleanUp() }

        #expect(throws: InstallationHandoff.HandoffError.self) {
            try InstallationHandoff.received(arguments: handoff.launchArguments, destination: directory.appending(path: "Other.app"), currentPID: 456)
        }
        #expect(throws: InstallationHandoff.HandoffError.self) {
            try InstallationHandoff.received(arguments: handoff.launchArguments, destination: destination, currentPID: 123)
        }
        #expect(try InstallationHandoff.received(arguments: ["Port Menu"], destination: destination, currentPID: 456) == nil)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PortMenuInstanceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        return directory
    }
}
