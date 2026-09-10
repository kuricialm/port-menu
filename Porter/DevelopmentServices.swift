import Foundation
import SwiftUI

@MainActor @Observable
final class DevelopmentServices {
    var routes: [UInt16: [URL]] = [:]
    var simulators: [RunningSimulator] = []
    var routeError: String?
    var simulatorError: String?
    var actionError: String?
    var busy: Set<String> = []
    private var isRefreshing = false

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        async let localRoutes = LocalCanRoutes.load()
        async let devices = RunningSimulator.scan()
        do { routes = try await localRoutes; routeError = nil }
        catch { routes = [:]; routeError = "LocalCan routes unavailable: \(error.localizedDescription)" }
        do { simulators = try await devices; simulatorError = nil }
        catch { simulatorError = "Simulator discovery unavailable. Check that Xcode is installed and selected." }
    }

    func perform(_ device: RunningSimulator, shutdown: Bool) {
        guard busy.insert(device.id).inserted else { return }
        Task {
            defer { busy.remove(device.id) }
            do {
                let scanner = LivePortScanner()
                if shutdown {
                    _ = try await scanner.runShell("/usr/bin/xcrun", args: ["simctl", "shutdown", device.id], timeout: 15)
                } else {
                    let developer = try await scanner.runShell("/usr/bin/xcode-select", args: ["-p"], timeout: 5).trimmingCharacters(in: .whitespacesAndNewlines)
                    _ = try await scanner.runShell("/usr/bin/open", args: ["-a", developer + "/Applications/Simulator.app", "--args", "-CurrentDeviceUDID", device.id], timeout: 10)
                }
                await refresh()
            } catch { actionError = error.localizedDescription }
        }
    }
}
