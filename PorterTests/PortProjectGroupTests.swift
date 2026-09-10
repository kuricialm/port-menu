import Foundation
import Testing
@testable import Port_Menu

struct PortProjectGroupTests {
    @Test func databaseAttachesToTheLocalCanServerAndRetainsAllEndpoints() {
        let root = URL(filePath: "/work/stock")
        let otherServer = entry(3000, root: root)
        let mainServer = entry(3210, root: root)
        let database = entry(55432, root: root, database: true)

        let groups = PortProjectGroup.make(entries: [database, mainServer, otherServer], localCanPorts: [3210])

        #expect(groups.map(\.primary.port) == [3000, 3210])
        #expect(groups[0].databases.isEmpty)
        #expect(groups[1].databases == [database])
        #expect(groups.reduce(0) { $0 + 1 + $1.databases.count } == 3)
        #expect(!groups[1].databases[0].canTerminate)
        #expect(!groups[1].databases[0].canOpenInBrowser)
    }

    @Test func fallsBackToTheLowestServerPortRegardlessOfInputOrder() {
        let root = URL(filePath: "/work/stock")
        let entries = [entry(55432, root: root, database: true), entry(3210, root: root), entry(3000, root: root)]
        let groups = PortProjectGroup.make(entries: entries, localCanPorts: [])
        #expect(groups.map(\.primary.port) == [3000, 3210])
        #expect(groups[0].databases.map(\.port) == [55432])
        #expect(groups[1].databases.isEmpty)
    }

    @Test func equalProjectNamesAtDifferentRootsDoNotCombine() {
        let server = entry(3210, root: URL(filePath: "/work/one/stock"))
        let database = entry(55432, root: URL(filePath: "/work/two/stock"), database: true)
        let groups = PortProjectGroup.make(entries: [server, database], localCanPorts: [3210])
        #expect(groups.map(\.primary) == [server, database])
        #expect(groups.allSatisfy { $0.databases.isEmpty })
    }

    @Test func unknownRootsDoNotCombineByName() {
        let server = entry(3210, root: nil)
        let database = entry(55432, root: nil, database: true)
        let groups = PortProjectGroup.make(entries: [server, database], localCanPorts: [3210])
        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.databases.isEmpty })
    }

    @Test func equivalentRootPathsCombine() {
        let server = entry(3210, root: URL(filePath: "/work/stock"))
        let database = entry(55432, root: URL(filePath: "/work/stock/subdirectory/../"), database: true)
        let groups = PortProjectGroup.make(entries: [server, database], localCanPorts: [])
        #expect(groups == [PortProjectGroup(primary: server, databases: [database])])
    }

    @Test func databaseRemainsVisibleWhenItsServerStops() {
        let database = entry(55432, root: URL(filePath: "/work/stock"), database: true)
        let groups = PortProjectGroup.make(entries: [database], localCanPorts: [3210])
        #expect(groups == [PortProjectGroup(primary: database, databases: [])])
    }

    @Test func canonicalRootsCombineThroughASymlink() throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let root = temporary.appending(path: "stock")
        let alias = temporary.appending(path: "stock-alias")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)

        let server = entry(3210, root: root)
        let database = entry(55432, root: alias, database: true)
        let groups = PortProjectGroup.make(entries: [server, database], localCanPorts: [])
        #expect(groups == [PortProjectGroup(primary: server, databases: [database])])
    }

    private func entry(_ port: UInt16, root: URL?, database: Bool = false) -> ActivePort {
        ActivePort(port: port, pid: Int32(port), projectName: "stock", branch: "main", startTime: nil,
                   owner: database ? .database(.postgreSQL) : .server, projectRoot: root)
    }
}
