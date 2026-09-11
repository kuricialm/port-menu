import AppKit
import Sparkle
import SwiftUI
import Testing
@testable import Port_Menu

struct MenuLayoutTests {
    @Test @MainActor func menuHasVisibleContentBeforeGeometryMeasurement() throws {
        let store = PortStore(scanner: FakePortScanner(ports: [], delay: 0))
        store.entries = [
            ActivePort(port: 3210, pid: 99999, projectName: "stock", branch: "main", startTime: Date().addingTimeInterval(-840), projectRoot: URL(filePath: "/work/stock")),
            ActivePort(port: 55432, pid: 99998, projectName: "stock", branch: "main", startTime: Date().addingTimeInterval(-493_200), owner: .database(.postgreSQL), projectRoot: URL(filePath: "/work/stock"))
        ]
        let services = DevelopmentServices()
        services.routes = [3210: [URL(string: "https://stock.local")!]]
        services.simulators = [RunningSimulator(udid: "sample", name: "iPhone 17 Pro Max", runtime: "iOS 27.0", appNames: ["Piqly"], startTime: Date().addingTimeInterval(-1980))]
        let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        let view = PortMainContentView(updater: updater.updater)
            .environment(services)
            .environment(store)
            .frame(width: 340)
            .background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .darkAqua)
        let size = host.fittingSize
        #expect(size.width == 340)
        #expect(size.height > 200)
        #expect(size.height < 580)
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try data.write(to: URL(fileURLWithPath: "/tmp/portmenu-layout.png"))
            }
        }
    }

    @Test @MainActor func portRowWithoutBranchKeepsTheSameTwoLineHeight() {
        let store = PortStore(scanner: FakePortScanner(ports: [], delay: 0))
        let services = DevelopmentServices()
        services.routes = [3100: [URL(string: "https://paperclip.local")!]]
        let withBranch = ActivePort(port: 3210, pid: 99999, projectName: "stock", branch: "main", startTime: Date().addingTimeInterval(-840))
        let withoutBranch = ActivePort(port: 3100, pid: 99997, projectName: "node", branch: "", startTime: Date().addingTimeInterval(-3480))
        let branched = NSHostingView(rootView: PortRow(entry: withBranch, showTopDivider: false)
            .environment(store).environment(services).frame(width: 340))
        let unbranched = NSHostingView(rootView: PortRow(entry: withoutBranch, showTopDivider: false)
            .environment(store).environment(services).frame(width: 340))
        #expect(abs(branched.fittingSize.height - unbranched.fittingSize.height) < 1)
    }

    @Test @MainActor func portRowRetainsOriginalTwoLineHeight() {
        let store = PortStore(scanner: FakePortScanner(ports: [], delay: 0))
        let services = DevelopmentServices()
        services.routes = [3210: [URL(string: "https://stock.local")!]]
        let entry = ActivePort(port: 3210, pid: 99999, projectName: "stock", branch: "main", startTime: Date().addingTimeInterval(-840))
        let host = NSHostingView(rootView: PortRow(entry: entry, showTopDivider: false)
            .environment(store).environment(services).frame(width: 340))
        #expect(host.fittingSize.height < 64)
        #expect(host.fittingSize.height > 35)
    }

    @Test @MainActor func groupedDatabaseUsesTheSameTwoLineContentHeight() {
        let store = PortStore(scanner: FakePortScanner(ports: [], delay: 0))
        let services = DevelopmentServices()
        let server = ActivePort(port: 3210, pid: 99999, projectName: "stock", branch: "main", startTime: Date())
        let database = ActivePort(port: 55432, pid: 99998, projectName: "stock", branch: "main", startTime: Date(), owner: .database(.postgreSQL))
        let plain = NSHostingView(rootView: PortRow(entry: server, showTopDivider: false)
            .environment(store).environment(services).frame(width: 340))
        let grouped = NSHostingView(rootView: PortRow(entry: server, showTopDivider: false, databases: [database])
            .environment(store).environment(services).frame(width: 340))

        #expect(grouped.fittingSize.width == 340)
        let databaseContent = NSHostingView(rootView: PortDatabaseRow(entry: database).frame(width: 308))
        let branchMeta = NSHostingView(rootView: PortServiceMetaRow(
            symbolName: "network", title: "main", startTime: Date(), port: 3210
        ).frame(width: 308))
        #expect(abs(databaseContent.fittingSize.height - branchMeta.fittingSize.height) < 1)
        #expect(abs(grouped.fittingSize.height - plain.fittingSize.height
                    - databaseContent.fittingSize.height - 6) < 1)
    }

    @Test func hidesEmptySectionsAndShowsCombinedCopy() {
        let portsOnly = MenuInventory(hasPorts: true, hasPortError: false, hasSimulators: false, hasSimulatorError: false)
        #expect(portsOnly.showsPorts)
        #expect(!portsOnly.showsSimulators)
        #expect(!portsOnly.showsCombinedEmpty)

        let simulatorsOnly = MenuInventory(hasPorts: false, hasPortError: false, hasSimulators: true, hasSimulatorError: false)
        #expect(!simulatorsOnly.showsPorts)
        #expect(simulatorsOnly.showsSimulators)
        #expect(!simulatorsOnly.showsCombinedEmpty)

        let empty = MenuInventory(hasPorts: false, hasPortError: false, hasSimulators: false, hasSimulatorError: false)
        #expect(empty.showsCombinedEmpty)
        #expect(!empty.showsPorts)
        #expect(!empty.showsSimulators)
    }
}
