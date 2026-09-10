import Darwin
import Foundation

/// The kernel releases this lock even if the owning app crashes. Keep the lock
/// file in place: deleting it would let a second process lock a different inode.
final class ApplicationInstanceLock {
    private var descriptor: Int32 = -1

    func acquire(at url: URL) throws -> Bool {
        if descriptor >= 0 { return true }
        let handle = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        guard handle >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(handle, LOCK_EX | LOCK_NB) == 0 else {
            let failure = errno
            Darwin.close(handle)
            if failure == EWOULDBLOCK { return false }
            throw POSIXError(POSIXErrorCode(rawValue: failure) ?? .EIO)
        }
        descriptor = handle
        return true
    }

    func release() {
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
    }

    deinit { if descriptor >= 0 { Darwin.close(descriptor) } }
}
