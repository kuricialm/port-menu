import Foundation

struct RunningSimulator: Identifiable, Sendable {
    var udid: String
    var name: String
    var runtime: String
    var deviceSetPath: String? = nil
    var dataPath: String? = nil
    var appNames: [String] = []

    var id: String { "\(deviceSetPath ?? "default")/\(udid)" }
    var isHostedByBitrig: Bool { deviceSetPath == Self.bitrigDeviceSet }
    var shutdownArguments: [String] {
        ["simctl"] + (deviceSetPath.map { ["--set", $0] } ?? []) + ["shutdown", udid]
    }

    static var bitrigDeviceSet: String {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Bitrig/Simulators").path
    }

    static func decode(_ data: Data, deviceSetPath: String? = nil) throws -> [RunningSimulator] {
        let response = try JSONDecoder().decode(DeviceList.self, from: data)
        var result: [RunningSimulator] = []
        for (runtime, devices) in response.devices {
            let suffix = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            let parts = suffix.split(separator: "-").map(String.init)
            let platform = parts.first ?? runtime
            let version = parts.dropFirst().joined(separator: ".")
            for device in devices where device.state == "Booted" && device.isAvailable != false {
                result.append(RunningSimulator(udid: device.udid, name: device.name, runtime: platform + " " + version,
                                               deviceSetPath: deviceSetPath, dataPath: device.dataPath))
            }
        }
        return result.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }
    }

    // launchd_sim exposes the device's bootstrap plist, including custom device
    // sets used by embedded simulators. Preserve spaces in these filesystem paths.
    static func activeDeviceSets(in processes: String) -> [String] {
        let suffix = "/data/var/run/launchd_bootstrap.plist"
        var paths: Set<String> = []
        for line in processes.split(separator: "\n") {
            let command = line.trimmingCharacters(in: .whitespaces)
            guard let separator = command.range(of: "launchd_sim "),
                  separator.lowerBound == command.startIndex || String(command[..<separator.lowerBound]).hasSuffix("/"),
                  command.hasSuffix(suffix) else { continue }
            let path = String(command[separator.upperBound...].dropLast(suffix.count))
            let device = URL(fileURLWithPath: path)
            guard path.hasPrefix("/"), UUID(uuidString: device.lastPathComponent) != nil else { continue }
            paths.insert(device.deletingLastPathComponent().standardizedFileURL.path)
        }
        return paths.sorted()
    }

    func runningAppBundlePaths(in processes: String) -> [String] {
        let root = dataPath ?? (deviceSetPath ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices").path) + "/\(udid)/data"
        let prefix = root + "/Containers/Bundle/Application/"
        return Array(Set(processes.split(separator: "\n").compactMap { line in
            let command = line.trimmingCharacters(in: .whitespaces)
            guard command.hasPrefix(prefix), let end = command.range(of: ".app/") else { return nil }
            return String(command[..<end.lowerBound]) + ".app"
        })).sorted()
    }

    static func scan() async -> Scan {
        let scanner = LivePortScanner()
        var warnings: [String] = []
        let processes: String
        do { processes = try await scanner.runShell("/bin/ps", args: ["-axo", "command="], timeout: 5) }
        catch { processes = ""; warnings.append("Running app names are unavailable.") }
        let defaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/CoreSimulator/Devices").path
        var customSets = Set(activeDeviceSets(in: processes))
        if FileManager.default.fileExists(atPath: bitrigDeviceSet) { customSets.insert(bitrigDeviceSet) }
        customSets.remove(defaultPath)
        let sets: [String?] = [nil] + customSets.sorted().map(Optional.some)
        var devices: [RunningSimulator] = []
        for path in sets {
            do {
                let args = ["simctl"] + (path.map { ["--set", $0] } ?? []) + ["list", "devices", "booted", "--json"]
                let json = try await scanner.runShell("/usr/bin/xcrun", args: args, timeout: 10)
                devices += try decode(Data(json.utf8), deviceSetPath: path)
            } catch {
                let label = path == bitrigDeviceSet ? "Bitrig" : path == nil ? "Xcode" : "Custom"
                warnings.append("\(label) simulator discovery unavailable.")
            }
        }
        for index in devices.indices {
            devices[index].appNames = devices[index].runningAppBundlePaths(in: processes).map { path in
                let bundle = Bundle(path: path)
                return bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            }.sorted()
        }
        return Scan(devices: devices.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name },
                    warning: warnings.isEmpty ? nil : warnings.joined(separator: " "))
    }

    struct Scan: Sendable { var devices: [RunningSimulator]; var warning: String? }
    private struct DeviceList: Decodable { var devices: [String: [Device]] }
    private struct Device: Decodable {
        var udid: String
        var name: String
        var state: String
        var isAvailable: Bool?
        var dataPath: String?
    }
}
