import Foundation
import Testing
@testable import Port_Menu

struct SimulatorDiscoveryTests {
    @Test func findsCustomDeviceSetsIncludingPathsWithSpaces() {
        let processes = """
        launchd_sim /Users/Dev User/Library/Bitrig/Simulators/05E5E380-477D-4F44-A3E5-1DFD1D57FEF4/data/var/run/launchd_bootstrap.plist
        launchd_sim /Users/Dev User/Library/Developer/CoreSimulator/Devices/2908F292-E5E5-49DC-B16A-EFC6F772D97E/data/var/run/launchd_bootstrap.plist
        /bin/sh -c launchd_sim /tmp/not-a-device/data/var/run/launchd_bootstrap.plist
        """
        #expect(RunningSimulator.activeDeviceSets(in: processes) == [
            "/Users/Dev User/Library/Bitrig/Simulators",
            "/Users/Dev User/Library/Developer/CoreSimulator/Devices"
        ])
    }

    @Test func customDevicesKeepTheirActionScopeAndAppPaths() throws {
        let json = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"05E5E380-477D-4F44-A3E5-1DFD1D57FEF4","name":"iPhone 17 Pro Max","state":"Booted","dataPath":"/custom/set/05E5E380-477D-4F44-A3E5-1DFD1D57FEF4/data"}]}}"#
        let custom = try #require(RunningSimulator.decode(Data(json.utf8), deviceSetPath: "/custom/set").first)
        let standard = try #require(RunningSimulator.decode(Data(json.utf8)).first)
        #expect(custom.id != standard.id)
        #expect(custom.shutdownArguments == ["simctl", "--set", "/custom/set", "shutdown", custom.udid])
        #expect(standard.shutdownArguments == ["simctl", "shutdown", standard.udid])
        let app = "/custom/set/\(custom.udid)/data/Containers/Bundle/Application/ABC/Interaction Arena.app"
        #expect(custom.runningAppBundlePaths(in: "\(app)/Interaction Arena\n/bin/sh -c \(app)/Interaction Arena") == [app])
    }

    @Test func recognizesEmbeddedBitrigDevices() {
        let device = RunningSimulator(udid: "device", name: "iPhone", runtime: "iOS 27.0", deviceSetPath: RunningSimulator.bitrigDeviceSet)
        #expect(device.isHostedByBitrig)
    }
}
