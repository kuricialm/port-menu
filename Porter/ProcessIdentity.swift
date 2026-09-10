import Foundation
import Darwin

/// Kernel start time distinguishes a process from a later reuse of the same PID.
struct ProcessIdentity: Hashable, Sendable {
    var pid: Int32
    var startSeconds: UInt64
    var startMicroseconds: UInt64

    var startTime: Date {
        Date(timeIntervalSince1970: Double(startSeconds) + Double(startMicroseconds) / 1_000_000)
    }
}

struct ProcessSnapshot: Sendable {
    var identity: ProcessIdentity
    var name: String
    var hasExited: Bool = false

    static func read(pid: Int32) throws -> ProcessSnapshot? {
        guard pid > 1 else { throw ProcessTerminationError.unverified }
        var info = proc_bsdinfo()
        let expectedSize = MemoryLayout<proc_bsdinfo>.size
        let count = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(expectedSize))
        guard count == expectedSize else {
            if Darwin.kill(pid, 0) == -1, errno == ESRCH { return nil }
            throw ProcessTerminationError.unverified
        }
        guard info.pbi_start_tvsec > 0 else { throw ProcessTerminationError.unverified }
        let name = withUnsafeBytes(of: info.pbi_name) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        let command = withUnsafeBytes(of: info.pbi_comm) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        return ProcessSnapshot(
            identity: ProcessIdentity(pid: pid, startSeconds: info.pbi_start_tvsec,
                                      startMicroseconds: info.pbi_start_tvusec),
            name: name.isEmpty ? command : name,
            hasExited: info.pbi_status == UInt32(SZOMB)
        )
    }
}
