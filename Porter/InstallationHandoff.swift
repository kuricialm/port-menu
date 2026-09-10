import Foundation

/// A private, one-use launch acknowledgement. The installed copy waits without
/// a menu or updater until its source exits and releases the instance lock.
struct InstallationHandoff: Codable {
    static let argument = "--port-menu-install-handoff"

    var parentPID: Int32
    var destination: URL
    var directory: URL

    static func create(destination: URL, parentPID: Int32, root: URL = FileManager.default.temporaryDirectory) throws -> Self {
        let directory = root.appending(path: "PortMenuHandoff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let handoff = Self(parentPID: parentPID, destination: destination.standardizedFileURL, directory: directory)
        do {
            try JSONEncoder().encode(handoff).write(to: directory.appending(path: "launch.json"), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        return handoff
    }

    static func received(arguments: [String], destination: URL, currentPID: Int32) throws -> Self? {
        guard let index = arguments.firstIndex(of: argument) else { return nil }
        guard arguments.indices.contains(index + 1) else { throw HandoffError.invalid }
        let directory = URL(filePath: arguments[index + 1]).standardizedFileURL
        let handoff = try JSONDecoder().decode(Self.self, from: Data(contentsOf: directory.appending(path: "launch.json")))
        guard handoff.directory.resolvingSymlinksInPath().path == directory.resolvingSymlinksInPath().path,
              handoff.destination.resolvingSymlinksInPath().path == destination.resolvingSymlinksInPath().path,
              handoff.parentPID > 0, handoff.parentPID != currentPID else {
            throw HandoffError.invalid
        }
        return handoff
    }

    var launchArguments: [String] { [Self.argument, directory.path] }

    func acknowledge(pid: Int32) throws {
        try Data(String(pid).utf8).write(to: directory.appending(path: "ready"), options: .atomic)
    }

    func isAcknowledged(by pid: Int32) -> Bool {
        guard let content = try? String(contentsOf: directory.appending(path: "ready"), encoding: .utf8) else { return false }
        return Int32(content) == pid
    }

    func cleanUp() { try? FileManager.default.removeItem(at: directory) }

    enum HandoffError: Error { case invalid }
}
