import Foundation

/// Presentation-only grouping; the store continues tracking every listening port.
struct PortProjectGroup: Identifiable, Equatable {
    var primary: ActivePort
    var databases: [ActivePort]

    var id: String { primary.id }

    static func make(entries: [ActivePort], localCanPorts: Set<UInt16>) -> [PortProjectGroup] {
        let ordered = entries.sorted {
            $0.port == $1.port ? $0.id < $1.id : $0.port < $1.port
        }
        let serversByRoot = Dictionary(grouping: ordered.filter {
            $0.canOpenInBrowser && $0.projectRoot != nil
        }, by: { $0.projectRoot!.path })
        let primaryByRoot = serversByRoot.mapValues { servers in
            servers.first { localCanPorts.contains($0.port) } ?? servers[0]
        }

        var attached: [String: [ActivePort]] = [:]
        var attachedIDs = Set<String>()
        for entry in ordered where !entry.canOpenInBrowser {
            guard let root = entry.projectRoot?.path, let primary = primaryByRoot[root] else { continue }
            attached[primary.id, default: []].append(entry)
            attachedIDs.insert(entry.id)
        }

        return ordered.filter { !attachedIDs.contains($0.id) }.map {
            PortProjectGroup(primary: $0, databases: attached[$0.id] ?? [])
        }
    }
}
