import SwiftUI
import os

// MARK: - PortStore

@MainActor
@Observable
final class PortStore {
    static let shared = PortStore()

    var entries: [ActivePort] = []
    var lastError: ScanError?
    var isScanning: Bool = false
    var lastDiagnostics: ScanDiagnostics?
    var lastSuccessfulScan: Date?
    var actionError: String?
    var terminatingPIDs: Set<Int32> = []

    var isStale: Bool { lastError != nil }
    var canKillPorts: Bool { !isStale && entries.contains { $0.canTerminate && !terminatingPIDs.contains($0.pid) } }

    private var storedInterval: Double {
        get { UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? RefreshInterval.defaultInterval.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "refreshInterval") }
    }

    var refreshInterval: RefreshInterval {
        get { RefreshInterval(rawValue: storedInterval) ?? .defaultInterval }
        set {
            storedInterval = newValue.rawValue
            restartTimer()
            Log.store.info("Refresh interval changed to \(newValue.rawValue)s")
        }
    }

    @ObservationIgnored private let scanner: PortScanning
    @ObservationIgnored private let terminator: any ProcessTerminating
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var refreshAfterCurrentScan = false
    @ObservationIgnored private var sleepObserver: Any?
    @ObservationIgnored private var wakeObserver: Any?

    init(scanner: PortScanning = LivePortScanner(), terminator: any ProcessTerminating = LiveProcessTerminator()) {
        self.scanner = scanner
        self.terminator = terminator
        setupLifecycleObservers()
        Log.lifecycle.info("PortStore initialized")
    }

    // MARK: - Polling

    func ensurePolling() {
        guard timer == nil else { return }
        Log.lifecycle.info("Starting polling (interval: \(self.refreshInterval.rawValue)s)")
        refresh()
        startTimer()
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = refreshInterval.rawValue
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    private func restartTimer() {
        guard timer != nil else { return }
        startTimer()
    }

    // MARK: - Refresh

    func refresh() {
        guard !isScanning else {
            refreshAfterCurrentScan = true
            if Log.isVerbose { Log.store.debug("Refresh skipped — already scanning") }
            return
        }

        scanTask?.cancel()
        isScanning = true
        scanTask = Task { [scanner] in
            defer {
                isScanning = false
                if refreshAfterCurrentScan && !Task.isCancelled {
                    refreshAfterCurrentScan = false
                    refresh()
                }
            }

            let result = await scanner.scan()

            guard !Task.isCancelled else { return }

            switch result {
            case .success(let ports, let diag):
                lastError = nil
                lastDiagnostics = diag
                lastSuccessfulScan = diag.timestamp
                applyUpdate(ports)

            case .failure(let error, _):
                lastError = error
                Log.store.error("Scan error: \(error.localizedDescription)")
            }
        }
    }

    /// Smoothly updates entries, preserving existing items during transition.
    private func applyUpdate(_ newEntries: [ActivePort]) {
        let oldIDs = Set(entries.map(\.port))
        let newIDs = Set(newEntries.map(\.port))

        if oldIDs == newIDs && entries.count == newEntries.count {
            var needsUpdate = false
            for (old, new) in zip(entries, newEntries) {
                if old != new { needsUpdate = true; break }
            }
            if !needsUpdate { return }
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            entries = newEntries
        }
    }

    // MARK: - Actions

    @discardableResult
    func killProcess(_ entry: ActivePort) async -> Bool {
        actionError = nil
        return await requestTermination(entry)
    }

    func killAllProcesses() {
        guard canKillPorts else { return }
        var seenPIDs: Set<Int32> = []
        let currentEntries = entries.filter { $0.canTerminate && seenPIDs.insert($0.pid).inserted }
        actionError = nil
        Task {
            for entry in currentEntries {
                await requestTermination(entry)
            }
        }
    }

    @discardableResult
    private func requestTermination(_ entry: ActivePort) async -> Bool {
        guard !terminatingPIDs.contains(entry.pid) else { return false }
        guard !isStale else {
            actionError = "Refresh the port list before stopping a server."
            return false
        }
        guard entries.contains(where: { $0.id == entry.id && $0.processIdentity == entry.processIdentity }) else {
            actionError = ProcessTerminationError.processChanged.localizedDescription
            return false
        }
        guard entry.canTerminate else {
            actionError = entry.terminationRestriction
            return false
        }

        terminatingPIDs.insert(entry.pid)
        defer {
            terminatingPIDs.remove(entry.pid)
            refresh()
        }
        do {
            try await terminator.terminate(entry)
            Log.store.info("Confirmed exit of PID \(entry.pid) on port \(entry.port)")
            return true
        } catch {
            let message = "\(entry.projectName) :\(entry.port) — \(error.localizedDescription)"
            actionError = [actionError, message].compactMap { $0 }.joined(separator: "\n")
            Log.store.error("Stop failed: \(message)")
            return false
        }
    }

    static func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: - Sleep / Wake

    private func setupLifecycleObservers() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSleep()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleWake()
            }
        }
    }

    private func handleSleep() {
        Log.lifecycle.info("System going to sleep — pausing polling")
        timer?.invalidate()
        timer = nil
        scanTask?.cancel()
        refreshAfterCurrentScan = false
    }

    private func handleWake() {
        Log.lifecycle.info("System woke — resuming polling")
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.ensurePolling()
        }
    }

    // MARK: - Diagnostics

    var diagnosticsSnapshot: String {
        """
        === Port Menu Diagnostics ===
        Ports found: \(entries.count)
        Is scanning: \(isScanning)
        Last error: \(lastError?.localizedDescription ?? "none")
        Refresh interval: \(refreshInterval.rawValue)s
        Last scan: \(lastDiagnostics?.summary ?? "none")
        Stale port data: \(isStale)
        Stopping PIDs: \(terminatingPIDs.sorted().map(String.init).joined(separator: ", "))
        Last action error: \(actionError ?? "none")
        Entries: \(entries.map { ":\($0.port) (\($0.projectName))" }.joined(separator: ", "))
        ============================
        """
    }
}
