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
    var scanDevices: @Sendable () async -> RunningSimulator.Scan = { await RunningSimulator.scan() }
    private var isRefreshing = false
    private var refreshAfterCurrentScan = false

    // The persistent menu-bar label owns this task so counts keep updating
    // when the popover is closed. The popover reads this same observable instance.
    func poll(refreshInterval: @MainActor () -> TimeInterval) async {
        while !Task.isCancelled {
            await refresh()
            do { try await Task.sleep(for: .seconds(refreshInterval())) }
            catch { break }
        }
    }

    func refresh() async {
        if isRefreshing {
            refreshAfterCurrentScan = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        repeat {
            refreshAfterCurrentScan = false
            async let localRoutes = LocalCanRoutes.load()
            async let devices = scanDevices()
            do {
                let result = try await localRoutes
                routes = result.routes
                routeError = result.warnings.isEmpty ? nil : result.warnings.joined(separator: "\n")
            }
            catch { routes = [:]; routeError = "LocalCan routes unavailable: \(error.localizedDescription)" }
            let scan = await devices
            withAnimation(.smooth(duration: 0.25)) { simulators = scan.devices }
            simulatorError = scan.warning
        } while refreshAfterCurrentScan
    }

    func perform(_ device: RunningSimulator, shutdown: Bool) {
        guard busy.insert(device.id).inserted else { return }
        Task {
            defer { busy.remove(device.id) }
            do {
                let scanner = LivePortScanner()
                if shutdown {
                    _ = try await scanner.runShell("/usr/bin/xcrun", args: device.shutdownArguments, timeout: 15)
                    simulators.removeAll { $0.id == device.id }
                } else if device.isHostedByBitrig {
                    // This device is embedded in Bitrig. Bring its host forward
                    // instead of trying to reopen it in Xcode's default device set.
                    _ = try await scanner.runShell("/usr/bin/open", args: ["-b", "app.bitrig.bitrigapp"], timeout: 10)
                } else {
                    let developer = try await scanner.runShell("/usr/bin/xcode-select", args: ["-p"], timeout: 5).trimmingCharacters(in: .whitespacesAndNewlines)
                    let arguments = ["-a", developer + "/Applications/Simulator.app", "--args"]
                        + (device.deviceSetPath.map { ["-DeviceSetPath", $0] } ?? [])
                        + ["-CurrentDeviceUDID", device.udid]
                    _ = try await scanner.runShell("/usr/bin/open", args: arguments, timeout: 10)
                }
                await refresh()
            } catch {
                actionError = error.localizedDescription
                await refresh()
            }
        }
    }
}
