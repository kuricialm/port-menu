import Testing
import Foundation
import Darwin
@testable import Port_Menu

struct ProcessTerminationTests {
    private let identity = ProcessIdentity(pid: 42_000, startSeconds: 1_700_000_000, startMicroseconds: 123)

    @Test func readsKernelIdentityOfCurrentProcessWithoutSignaling() throws {
        let firstSnapshot = try ProcessSnapshot.read(pid: getpid())
        let secondSnapshot = try ProcessSnapshot.read(pid: getpid())
        let first = try #require(firstSnapshot)
        let second = try #require(secondSnapshot)
        #expect(first.identity == second.identity)
        #expect(first.identity.pid == getpid())
        #expect(first.identity.startTime <= Date())
    }

    @Test func protectsSharedDockerOwner() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "node"))
        let entry = port(owner: .sharedDocker)
        #expect(!entry.canTerminate)
        await #expect(throws: ProcessTerminationError.sharedOwner) {
            try await LiveProcessTerminator(control: control).terminate(entry)
        }
        #expect(control.signalCount == 0)
    }

    @Test func protectsDockerEvenWhenCachedRowWasClassifiedAsServer() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "com.docker.backend"))
        await #expect(throws: ProcessTerminationError.sharedOwner) {
            try await LiveProcessTerminator(control: control).terminate(port())
        }
        #expect(control.signalCount == 0)
    }

    @Test func protectsDatabaseOwnerBeforeAnySignal() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "postgres"))
        let database = port(owner: .database(.postgreSQL))
        #expect(!database.canTerminate)
        #expect(!database.canOpenInBrowser)
        #expect(database.ownerLabel == "PostgreSQL")
        await #expect(throws: ProcessTerminationError.databaseOwner(.postgreSQL)) {
            try await LiveProcessTerminator(control: control).terminate(database)
        }
        #expect(control.signalCount == 0)
    }

    @Test func protectsLiveDatabaseEvenWhenCachedRowSaidServer() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "postgres"))
        await #expect(throws: ProcessTerminationError.databaseOwner(.postgreSQL)) {
            try await LiveProcessTerminator(control: control).terminate(port())
        }
        #expect(control.signalCount == 0)
    }

    @Test func rejectsReusedPIDBeforeSignaling() async {
        var replacement = identity
        replacement.startMicroseconds += 1
        let control = TestProcessControl(snapshot: .init(identity: replacement, name: "node"))
        await #expect(throws: ProcessTerminationError.processChanged) {
            try await LiveProcessTerminator(control: control).terminate(port())
        }
        #expect(control.signalCount == 0)
        #expect(port().id != port(identity: replacement).id)
    }

    @Test func refusesProcessThatNoLongerOwnsSelectedPort() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "node"), listening: false)
        await #expect(throws: ProcessTerminationError.noLongerListening) {
            try await LiveProcessTerminator(control: control).terminate(port())
        }
        #expect(control.signalCount == 0)
    }

    @Test func reportsPermissionFailure() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "node"), signalError: .signalFailed(EPERM))
        await #expect(throws: ProcessTerminationError.signalFailed(EPERM)) {
            try await LiveProcessTerminator(control: control).terminate(port())
        }
        #expect(control.signalCount == 1)
    }

    @Test func reportsIgnoredTerminationWithoutEscalatingSignal() async {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "node"), exitsOnSignal: false)
        await #expect(throws: ProcessTerminationError.stillRunning) {
            try await LiveProcessTerminator(control: control, exitTimeout: .milliseconds(20)).terminate(port())
        }
        #expect(control.signalCount == 1)
    }

    @Test func confirmsExitAfterSuccessfulSignal() async throws {
        let control = TestProcessControl(snapshot: .init(identity: identity, name: "node"))
        try await LiveProcessTerminator(control: control).terminate(port())
        #expect(control.signalCount == 1)
    }

    private func port(identity: ProcessIdentity? = nil, owner: PortOwner = .server) -> ActivePort {
        let processIdentity = identity ?? self.identity
        return ActivePort(port: 55000, pid: processIdentity.pid, projectName: "test", branch: "main",
                          startTime: processIdentity.startTime, processIdentity: processIdentity, owner: owner)
    }
}

@Suite(.serialized)
struct PortTerminationStateTests {
    private var entry: ActivePort {
        let identity = ProcessIdentity(pid: 42_000, startSeconds: 1_700_000_000, startMicroseconds: 123)
        return ActivePort(port: 3000, pid: identity.pid, projectName: "test", branch: "main",
                          startTime: identity.startTime, processIdentity: identity)
    }

    @Test @MainActor func failedSignalKeepsActivePortVisibleAndShowsError() async {
        let terminator = TestTerminator(error: .signalFailed(EPERM))
        let store = PortStore(scanner: FakePortScanner(ports: [entry], delay: 0), terminator: terminator)
        store.entries = [entry]
        let stopped = await store.killProcess(entry)
        #expect(!stopped)
        #expect(store.entries == [entry])
        #expect(store.actionError?.contains("Could not stop") == true)
        #expect(store.terminatingPIDs.isEmpty)
        await waitForScan(store)
        #expect(store.entries == [entry])
    }

    @Test @MainActor func rapidRestartOnSamePortIsNeverSuppressed() async {
        let identity = ProcessIdentity(pid: 42_001, startSeconds: 1_700_000_001, startMicroseconds: 999)
        let restarted = ActivePort(port: entry.port, pid: identity.pid, projectName: "test", branch: "main",
                               startTime: identity.startTime, processIdentity: identity)
        let store = PortStore(scanner: FakePortScanner(ports: [restarted], delay: 0), terminator: TestTerminator())
        store.entries = [entry]
        #expect(await store.killProcess(entry))
        await waitForScan(store)
        #expect(store.entries == [restarted])
    }

    @Test @MainActor func bulkTerminationSkipsSharedAndDatabaseOwnersAndSignalsEachPIDOnce() async {
        let terminator = TestTerminator()
        let sharedIdentity = ProcessIdentity(pid: 42_001, startSeconds: 1, startMicroseconds: 0)
        let shared = ActivePort(port: 4000, pid: sharedIdentity.pid, projectName: "Docker", branch: "",
                                startTime: sharedIdentity.startTime, processIdentity: sharedIdentity, owner: .sharedDocker)
        let secondPort = ActivePort(port: 5173, pid: entry.pid, projectName: "test", branch: "main",
                                    startTime: entry.startTime, processIdentity: entry.processIdentity)
        let databaseIdentity = ProcessIdentity(pid: 42_002, startSeconds: 1, startMicroseconds: 0)
        let database = ActivePort(port: 55432, pid: databaseIdentity.pid, projectName: "test", branch: "main",
                                  startTime: databaseIdentity.startTime, processIdentity: databaseIdentity, owner: .database(.postgreSQL))
        let ports = [entry, secondPort, shared, database]
        let store = PortStore(scanner: FakePortScanner(ports: ports, delay: 0), terminator: terminator)
        store.entries = ports
        store.killAllProcesses()
        for _ in 0..<50 {
            if await terminator.calls.count == 1 { break }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(await terminator.calls == [entry.id])
        #expect(store.entries.contains(shared))
        #expect(store.entries.contains(database))
    }

    @Test @MainActor func failedScanMarksRetainedDataStaleAndBlocksTermination() async {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let scanner = SequencePortScanner(results: [
            .success([entry], ScanDiagnostics(duration: 0, portsFound: 1, dataSource: "test", timestamp: date)),
            .failure(.lsofTimeout, [])
        ])
        let terminator = TestTerminator()
        let store = PortStore(scanner: scanner, terminator: terminator)
        store.refresh()
        await waitForScan(store)
        #expect(store.lastSuccessfulScan == date)
        store.refresh()
        await waitForScan(store)
        #expect(store.isStale)
        #expect(store.entries == [entry])
        #expect(store.lastSuccessfulScan == date)
        #expect(!store.canKillPorts)
        #expect(!(await store.killProcess(entry)))
        #expect(await terminator.calls.isEmpty)
    }

    @MainActor private func waitForScan(_ store: PortStore) async {
        for _ in 0..<100 where store.isScanning {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(!store.isScanning)
    }
}

private final class TestProcessControl: ProcessControl, @unchecked Sendable {
    private let lock = NSLock()
    private var process: ProcessSnapshot?
    private var signalCalls = 0
    private let listening: Bool
    private let signalError: ProcessTerminationError?
    private let exitsOnSignal: Bool

    var signalCount: Int { lock.withLock { signalCalls } }

    init(snapshot: ProcessSnapshot, listening: Bool = true, signalError: ProcessTerminationError? = nil, exitsOnSignal: Bool = true) {
        self.process = snapshot
        self.listening = listening
        self.signalError = signalError
        self.exitsOnSignal = exitsOnSignal
    }

    func snapshot(pid: Int32) throws -> ProcessSnapshot? { lock.withLock { process } }
    func isListening(pid: Int32, port: UInt16) async throws -> Bool { listening }
    func sendTermination(pid: Int32) throws {
        try lock.withLock {
            signalCalls += 1
            if let signalError { throw signalError }
            if exitsOnSignal { process = nil }
        }
    }
}

private actor TestTerminator: ProcessTerminating {
    var calls: [String] = []
    var error: ProcessTerminationError?

    init(error: ProcessTerminationError? = nil) { self.error = error }

    func terminate(_ entry: ActivePort) async throws {
        calls.append(entry.id)
        if let error { throw error }
    }
}

private actor SequencePortScanner: PortScanning {
    var results: [ScanResult]

    init(results: [ScanResult]) { self.results = results }
    func scan() async -> ScanResult {
        results.count > 1 ? results.removeFirst() : results[0]
    }
}
