import Foundation
import Testing
@testable import Port_Menu

struct LocalCanRoutesTests {
    @Test func malformedProjectDoesNotRemoveOtherProjects() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try validProject.write(to: directory.appending(path: "good.yml"), atomically: true, encoding: .utf8)
        try "services: [invalid yaml".write(to: directory.appending(path: "broken.yml"), atomically: true, encoding: .utf8)

        let result = try await LocalCanRoutes.load(projectsDirectory: directory)
        #expect(result.routes[3210]?.map(\.absoluteString) == ["https://example.local"])
        #expect(result.warnings.count == 1)
        #expect(result.warnings.first?.contains("broken.yml") == true)
        #expect(try String(contentsOf: directory.appending(path: "good.yml"), encoding: .utf8) == validProject)
    }

    @Test func malformedServiceAndEndpointDoNotRemoveValidNeighbors() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let yaml = """
        services:
          malformed: bad service
          badTarget:
            target: 'http://localhost:wrong'
          valid:
            target: 'http://127.0.0.1:3210'
            endpoints:
              - enabled: true
                scheme: https
                url: 'invalid host.local'
              - enabled: true
                scheme: https
                url: example.local
          nonLocal:
            target: 'https://example.com:3210'
            endpoints:
              - enabled: true
                scheme: https
                url: external.local
        """
        try yaml.write(to: directory.appending(path: "mixed.yaml"), atomically: true, encoding: .utf8)
        let result = try await LocalCanRoutes.load(projectsDirectory: directory)
        #expect(result.routes[3210]?.map(\.absoluteString) == ["https://example.local"])
        #expect(result.warnings.count == 3)
        #expect(result.warnings.allSatisfy { $0.contains("mixed.yaml") })
    }

    @Test func rejectsYAMLObjectsWithoutExecutingThem() async throws {
        let directory = try fixtureDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "--- !ruby/object:Object {}".write(to: directory.appending(path: "unsafe.yml"), atomically: true, encoding: .utf8)
        let result = try await LocalCanRoutes.load(projectsDirectory: directory)
        #expect(result.routes.isEmpty)
        #expect(result.warnings.count == 1)
    }

    @Test func absentLocalCanDirectoryHasNoWarnings() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let result = try await LocalCanRoutes.load(projectsDirectory: directory)
        #expect(result.routes.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    private func fixtureDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PortMenuLocalCan-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private var validProject: String {
        """
        services:
          web:
            target: http://127.0.0.1:3210
            endpoints:
              - enabled: true
                scheme: https
                url: example.local
        """
    }
}
