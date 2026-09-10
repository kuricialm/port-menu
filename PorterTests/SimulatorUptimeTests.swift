import Foundation
import Testing
@testable import Port_Menu

struct SimulatorUptimeTests {
    @Test func readsActualBootTimeAndPreservesCommandsWithSpaces() throws {
        let devicePath = "/Users/Dev User/Library/Bitrig/Simulators/05E5E380-477D-4F44-A3E5-1DFD1D57FEF4"
        let commands = """
        Thu Sep  3 21:08:07 2026     launchd_sim \(devicePath)/data/var/run/launchd_bootstrap.plist
        Thu Sep  3 21:10:00 2026     \(devicePath)/data/Containers/Bundle/Application/ABC/Interaction Arena.app/Interaction Arena
        """
        let snapshot = RunningSimulator.processSnapshot(commands)
        let start = try #require(snapshot.bootTimes[devicePath])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        #expect(calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)
            == DateComponents(year: 2026, month: 9, day: 3, hour: 21, minute: 8, second: 7))
        #expect(snapshot.commands.contains("Interaction Arena.app/Interaction Arena"))
        #expect(RunningSimulator.activeDeviceSets(in: snapshot.commands) == ["/Users/Dev User/Library/Bitrig/Simulators"])
        #expect(snapshot.bootTimes.count == 1)
    }

    @Test func rebootReplacesSessionStartRatherThanUsingAppStart() throws {
        let path = "/custom/05E5E380-477D-4F44-A3E5-1DFD1D57FEF4"
        let first = RunningSimulator.processSnapshot("Thu Sep 10 10:00:00 2026 launchd_sim \(path)/data/var/run/launchd_bootstrap.plist")
        let rebooted = RunningSimulator.processSnapshot("Thu Sep 10 11:00:00 2026 launchd_sim \(path)/data/var/run/launchd_bootstrap.plist")
        let firstStart = try #require(first.bootTimes[path])
        let secondStart = try #require(rebooted.bootTimes[path])
        #expect(secondStart.timeIntervalSince(firstStart) == 3600)
    }

    @Test func missingOrInvalidBootTimeIsNotInvented() {
        let snapshot = RunningSimulator.processSnapshot("invalid process data")
        #expect(snapshot.bootTimes.isEmpty)
    }

    @Test func elapsedLabelChangesAtMinuteAndHourBoundaries() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        #expect(formatUptime(from: start, now: start.addingTimeInterval(59)) == "<1m")
        #expect(formatUptime(from: start, now: start.addingTimeInterval(60)) == "1m")
        #expect(formatUptime(from: start, now: start.addingTimeInterval(3600)) == "1h 0m")
        #expect(formatUptime(from: start, now: start.addingTimeInterval(86400)) == "1d 0h")
    }
}
