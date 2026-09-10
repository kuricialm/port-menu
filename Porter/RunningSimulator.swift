import Foundation

struct RunningSimulator: Identifiable, Sendable {
    var id: String
    var name: String
    var runtime: String
    var appNames: [String] = []

    static func decode(_ data: Data) throws -> [RunningSimulator] {
        let response = try JSONDecoder().decode(DeviceList.self, from: data)
        var result: [RunningSimulator] = []
        for (runtime, devices) in response.devices {
            let suffix = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            let parts = suffix.split(separator: "-").map(String.init)
            let platform = parts.first ?? runtime
            let version = parts.dropFirst().joined(separator: ".")
            for device in devices where device.state == "Booted" && device.isAvailable != false {
                result.append(RunningSimulator(id: device.udid, name: device.name, runtime: platform + " " + version))
            }
        }
        return result.sorted { $0.name == $1.name ? $0.id < $1.id : $0.name < $1.name }
    }

    static func scan() async throws -> [RunningSimulator] {
        let scanner = LivePortScanner()
        let json = try await scanner.runShell("/usr/bin/xcrun", args: ["simctl", "list", "devices", "booted", "--json"], timeout: 10)
        var devices = try decode(Data(json.utf8))
        guard !devices.isEmpty else { return devices }
        let processes = try await scanner.runShell("/bin/ps", args: ["-axo", "command="], timeout: 5)
        for index in devices.indices {
            let marker = "/" + devices[index].id + "/data/Containers/Bundle/Application/"
            var names: Set<String> = []
            for line in processes.split(separator: "\n") {
                guard line.contains(marker), let end = line.range(of: ".app/") else { continue }
                let path = String(line[..<end.lowerBound]) + ".app"
                let bundle = Bundle(path: path.trimmingCharacters(in: .whitespaces))
                let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                names.insert(name)
            }
            devices[index].appNames = names.sorted()
        }
        return devices
    }

    private struct DeviceList: Decodable { var devices: [String: [Device]] }
    private struct Device: Decodable {
        var udid: String
        var name: String
        var state: String
        var isAvailable: Bool?
    }
}
