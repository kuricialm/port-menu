import AppKit
import Sparkle
import SwiftUI
import Testing
@testable import Port_Menu

struct MenuLayoutTests {
    @Test @MainActor func menuHasVisibleContentBeforeGeometryMeasurement() throws {
        let store = PortStore(scanner: FakePortScanner(ports: [], delay: 0))
        store.entries = [ActivePort(port: 3210, pid: 99999, projectName: "stock", branch: "main", startTime: nil)]
        let services = DevelopmentServices()
        services.routes = [3210: [URL(string: "https://stock.local")!]]
        services.simulators = [RunningSimulator(udid: "sample", name: "iPhone 17 Pro Max", runtime: "iOS 27.0", appNames: ["Piqly"])]
        let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        let view = PortMainContentView(updater: updater.updater, services: services)
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

    @Test @MainActor func portRowRetainsOriginalTwoLineHeight() {
        let store = PortStore(scanner: FakePortScanner(ports: [], delay: 0))
        let services = DevelopmentServices()
        services.routes = [3210: [URL(string: "https://stock.local")!]]
        let entry = ActivePort(port: 3210, pid: 99999, projectName: "stock", branch: "main", startTime: nil)
        let host = NSHostingView(rootView: PortRow(entry: entry, showTopDivider: false)
            .environment(store).environment(services).frame(width: 340))
        #expect(host.fittingSize.height < 64)
        #expect(host.fittingSize.height > 35)
    }
}
