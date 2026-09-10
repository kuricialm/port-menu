import Foundation

// MARK: - Port Model

struct ActivePort: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let port: UInt16
    let pid: Int32
    let projectName: String
    let projectRoot: URL?
    let branch: String
    let startTime: Date?
    let processIdentity: ProcessIdentity?
    let owner: PortOwner

    var terminationRestriction: String? {
        if owner == .sharedDocker {
            return "Manage this port in Docker; its process is shared by other containers."
        }
        if case .database(let engine) = owner {
            return "Manage \(engine.displayName) with its database tools; this is not a web server."
        }
        if processIdentity?.pid != pid || pid <= 1 {
            return "The server process could not be verified. Refresh and try again."
        }
        return nil
    }

    var canTerminate: Bool { terminationRestriction == nil }
    var canOpenInBrowser: Bool {
        if case .database = owner { return false }
        return true
    }
    var ownerLabel: String? {
        if case .database(let engine) = owner { return engine.displayName }
        return nil
    }

    var url: URL {
        URL(string: "http://localhost:\(port)")!
    }

    init(port: UInt16, pid: Int32, projectName: String, branch: String, startTime: Date?,
         processIdentity: ProcessIdentity? = nil, owner: PortOwner = .server, projectRoot: URL? = nil) {
        if let processIdentity {
            self.id = "\(port)-\(pid)-\(processIdentity.startSeconds)-\(processIdentity.startMicroseconds)"
        } else {
            self.id = "\(port)-\(pid)"
        }
        self.port = port
        self.pid = pid
        self.projectName = projectName
        self.projectRoot = projectRoot?.standardizedFileURL.resolvingSymlinksInPath()
        self.branch = branch
        self.startTime = startTime
        self.processIdentity = processIdentity
        self.owner = owner
    }
}

enum PortOwner: Hashable, Sendable {
    case server
    case sharedDocker
    case database(DatabaseEngine)
}

enum DatabaseEngine: Hashable, Sendable {
    case postgreSQL

    var displayName: String {
        switch self {
        case .postgreSQL: "PostgreSQL"
        }
    }
}

// MARK: - Scan Result

enum ScanResult: Sendable {
    case success([ActivePort], ScanDiagnostics)
    case failure(ScanError, [ActivePort])
}

struct ScanDiagnostics: Sendable {
    let duration: TimeInterval
    let portsFound: Int
    let dataSource: String
    let timestamp: Date

    var summary: String {
        let ms = (duration * 1000).formatted(.number.precision(.fractionLength(1)))
        let time = timestamp.formatted(date: .omitted, time: .standard)
        return "Scan: \(ms)ms | \(portsFound) ports | source: \(dataSource) | \(time)"
    }
}

enum ScanError: Error, Sendable, LocalizedError {
    case lsofFailed(String)
    case lsofTimeout

    var errorDescription: String? {
        switch self {
        case .lsofFailed(let msg): return "Port scan failed: \(msg)"
        case .lsofTimeout: return "Port scan timed out"
        }
    }
}

// MARK: - Refresh Interval

enum RefreshInterval: Double, CaseIterable, Sendable {
    case fast = 2
    case normal = 5
    case relaxed = 10
    case slow = 30

    static let defaultInterval: RefreshInterval = .normal
}
