import Foundation
import Testing
@testable import Port_Menu

struct SimulatorToolchainTests {
    @Test func commandLineToolsSelectionFallsBackToRegisteredXcode() throws {
        let tools = try SimulatorToolchain.select(
            environmentDirectory: nil,
            selectedDirectory: "/Library/Developer/CommandLineTools",
            installedApplications: [URL(filePath: "/Applications/Xcode-beta.app")],
            isExecutable: { $0 == "/Applications/Xcode-beta.app/Contents/Developer/usr/bin/simctl" }
        )
        #expect(tools.developerDirectory == "/Applications/Xcode-beta.app/Contents/Developer")
        #expect(tools.environment == ["DEVELOPER_DIR": tools.developerDirectory])
    }

    @Test func explicitXcodeWinsAndAcceptsAnAppBundlePath() throws {
        let tools = try SimulatorToolchain.select(
            environmentDirectory: "/Volumes/Dev Tools/Xcode.app",
            selectedDirectory: "/Applications/Xcode.app/Contents/Developer",
            installedApplications: [URL(filePath: "/Applications/Xcode-beta.app")],
            isExecutable: { $0.hasSuffix("/usr/bin/simctl") }
        )
        #expect(tools.developerDirectory == "/Volumes/Dev Tools/Xcode.app/Contents/Developer")
    }

    @Test func invalidOverrideFallsBackToSelectedXcode() throws {
        let tools = try SimulatorToolchain.select(
            environmentDirectory: "/missing/Xcode.app",
            selectedDirectory: "/Applications/Xcode.app/Contents/Developer\n",
            installedApplications: [URL(filePath: "/Applications/Xcode-beta.app")],
            isExecutable: { !$0.hasPrefix("/missing/") }
        )
        #expect(tools.developerDirectory == "/Applications/Xcode.app/Contents/Developer")
    }

    @Test func registeredCandidatesHaveStableOrderAndSkipUnusableCopies() throws {
        let apps = ["/Z/Xcode.app", "/A/Xcode.app", "/B/Xcode.app"].map { URL(filePath: $0) }
        for candidates in [apps, apps.reversed().map { $0 }] {
            let tools = try SimulatorToolchain.select(
                environmentDirectory: nil, selectedDirectory: nil, installedApplications: candidates,
                isExecutable: { !$0.hasPrefix("/A/") }
            )
            #expect(tools.developerDirectory == "/B/Xcode.app/Contents/Developer")
        }
    }

    @Test func missingSimulatorToolsProducesAnActionableError() {
        #expect(throws: SimulatorToolchainError.missingXcode) {
            try SimulatorToolchain.select(
                environmentDirectory: "", selectedDirectory: "/Library/Developer/CommandLineTools",
                installedApplications: [], isExecutable: { _ in false }
            )
        }
    }

    @Test func discoveredDeviceKeepsToolchainAndCustomSetForActions() throws {
        let tools = try SimulatorToolchain.select(
            environmentDirectory: "/Applications/Xcode-beta.app", selectedDirectory: nil,
            installedApplications: [], isExecutable: { _ in true }
        )
        let json = #"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"test-device","name":"iPhone","state":"Booted"}]}}"#
        let device = try #require(RunningSimulator.decode(
            Data(json.utf8), deviceSetPath: "/custom device set", toolchain: tools
        ).first)
        #expect(device.toolchain == tools)
        #expect(device.shutdownArguments == ["simctl", "--set", "/custom device set", "shutdown", "test-device"])
        #expect(device.showArguments(using: tools) == [
            "-a", "/Applications/Xcode-beta.app/Contents/Developer/Applications/Simulator.app",
            "--args", "-DeviceSetPath", "/custom device set", "-CurrentDeviceUDID", "test-device"
        ])
    }
}
