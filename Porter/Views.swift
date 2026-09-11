import ServiceManagement
import Sparkle
import SwiftUI

// MARK: - Check for Updates

struct CheckForUpdatesView: View {
    let updater: SPUUpdater
    @State private var canCheckForUpdates = false

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!canCheckForUpdates)
        .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheckForUpdates = $0 }
    }
}

// MARK: - Port List

struct PortListView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PortStore.self) private var store
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    var updater: SPUUpdater

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                PortMainContentView(updater: updater)
            } else {
                OnboardingView()
            }
        }
        .frame(width: 340)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: hasCompletedOnboarding)
    }
}

// MARK: - Main Content

struct PortMainContentView: View {
    @Environment(PortStore.self) private var store
    var updater: SPUUpdater

    @Environment(DevelopmentServices.self) private var services
    @State private var contentHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PortHeaderView(updater: updater)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let inventory = MenuInventory(
                        hasPorts: !store.entries.isEmpty,
                        hasPortError: store.lastError != nil,
                        hasSimulators: !services.simulators.isEmpty,
                        hasSimulatorError: services.simulatorError != nil
                    )
                    let showPorts = inventory.showsPorts
                    let showSimulators = inventory.showsSimulators
                    if showPorts {
                        MenuSectionHeader("Ports")
                        if let error = store.lastError, store.entries.isEmpty {
                            PortErrorStateView(error: error)
                        } else {
                            PortEntryListView()
                        }
                        if store.isStale, !store.entries.isEmpty {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ports may be out of date")
                                    if let date = store.lastSuccessfulScan {
                                        Text("Last scanned \(date.formatted(date: .omitted, time: .shortened))")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                Button("Retry") { store.refresh() }
                                    .buttonStyle(.plain)
                            }
                            .font(.caption).foregroundStyle(.orange)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .help(store.lastError?.localizedDescription ?? "")
                        }
                        if let error = services.routeError {
                            Text(error).font(.caption).foregroundStyle(.secondary).padding(16)
                        }
                    }
                    if showPorts && showSimulators {
                        Divider()
                    }
                    if showSimulators {
                        SimulatorSectionView()
                    }
                    if inventory.showsCombinedEmpty {
                        MenuSectionHeader("Ports")
                        if store.isScanning {
                            PortScanningStateView()
                        } else {
                            Text("No running ports or simulators")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .accessibilityLabel("No running ports or simulators")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: MenuContentHeightKey.self, value: geometry.size.height)
                    }
                }
            }
            // A menu window asks for an intrinsic size. A maximum alone lets
            // ScrollView report zero height and hides every row below the header.
            .frame(height: min(max(contentHeight, 1), 520))
            .onPreferenceChange(MenuContentHeightKey.self) { height in
                if height > 0 { contentHeight = height }
            }
        }
        .alert("Action Failed", isPresented: Binding(
            get: { services.actionError != nil || store.actionError != nil },
            set: { if !$0 { services.actionError = nil; store.actionError = nil } }
        )) {
            Button("OK") { services.actionError = nil; store.actionError = nil }
        } message: { Text(services.actionError ?? store.actionError ?? "") }
    }
}

struct MenuSectionHeader: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }
}

struct MenuInventory {
    var hasPorts: Bool
    var hasPortError: Bool
    var hasSimulators: Bool
    var hasSimulatorError: Bool

    var showsPorts: Bool { hasPorts || hasPortError }
    var showsSimulators: Bool { hasSimulators || hasSimulatorError }
    var showsCombinedEmpty: Bool { !showsPorts && !showsSimulators }
}

private struct MenuContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Header

struct PortHeaderView: View {
    @Environment(PortStore.self) private var store
    @State private var menuHovered = false
    @State private var showMenu = false
    @State private var launchAtLoginError: String?
    var updater: SPUUpdater

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLoginError = error.localizedDescription
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("Port Menu").font(.headline)
            Spacer()

            HStack(spacing: 2) {
                if !store.entries.isEmpty {
                    HeaderControlButton(
                        tooltip: "Stop eligible servers; simulators and shared backends stay running",
                        destructive: true,
                        action: store.killAllProcesses
                    ) {
                        Text("Kill ports")
                    }
                    .disabled(store.isStale || !store.terminatingPIDs.isEmpty || !store.entries.contains(where: \.canTerminate))
                }

                HeaderControlButton(
                    tooltip: "Quit Port Menu",
                    action: { NSApplication.shared.terminate(nil) }
                ) {
                    HeaderIconLabel(systemName: "power")
                }
                .accessibilityLabel("Quit Port Menu")

                Button { showMenu.toggle() } label: {
                    HeaderIconLabel(systemName: "ellipsis")
                }
                .accessibilityLabel("Settings")
                .buttonStyle(HeaderButtonStyle(isHovered: menuHovered))
                .background(FloatingTooltipAnchor(text: "Settings", isVisible: menuHovered && !showMenu))
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        menuHovered = hovering
                    }
                }
                .popover(isPresented: $showMenu, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Port Menu \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Toggle("Launch at Login", isOn: launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)

                        Divider()

                        UpdateSettingsView(updater: updater)
                        CheckForUpdatesView(updater: updater)
                    }
                    .padding(12)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .alert("Couldn't Update Launch at Login", isPresented: launchAtLoginErrorBinding) {
            Button("OK") { launchAtLoginError = nil }
        } message: {
            Text(launchAtLoginError ?? "Port Menu couldn't change its launch-at-login setting.")
        }
    }

    private var launchAtLoginErrorBinding: Binding<Bool> {
        Binding(
            get: { launchAtLoginError != nil },
            set: { newValue in
                if !newValue { launchAtLoginError = nil }
            }
        )
    }
}

struct HeaderControlButton<Label: View>: View {
    let tooltip: String?
    var destructive: Bool = false
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(HeaderButtonStyle(destructive: destructive, isHovered: isHovered))
        .background(FloatingTooltipAnchor(text: tooltip, isVisible: isHovered))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct HeaderIconLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: NSFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .medium))
            .frame(width: 12, height: 14)
    }
}

struct HeaderButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var destructive: Bool = false
    var isHovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 4)
            .background(Capsule().fill(backgroundColor(configuration)))
            .foregroundStyle(foregroundColor)
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.92 : isHovered ? 1.04 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
    }

    private var horizontalPadding: CGFloat { destructive ? 10 : 7 }

    private func backgroundColor(_ c: ButtonStyleConfiguration) -> Color {
        if destructive {
            if c.isPressed { return .red.opacity(0.18) }
            return isHovered ? .red.opacity(0.12) : .clear
        }
        if c.isPressed { return .primary.opacity(0.14) }
        return isHovered ? .primary.opacity(0.08) : .clear
    }

    private var foregroundColor: Color {
        if destructive {
            return isHovered ? .red : .secondary
        }
        return .secondary
    }
}

// MARK: - Entry List

struct PortEntryListView: View {
    @Environment(PortStore.self) private var store
    @Environment(DevelopmentServices.self) private var services
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let groups = PortProjectGroup.make(entries: store.entries, localCanPorts: Set(services.routes.keys))
        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            PortRow(entry: group.primary, showTopDivider: index > 0, databases: group.databases)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .opacity,
                    removal: .modifier(active: PortExitEffect(hidden: true), identity: PortExitEffect(hidden: false))
                ))
        }
        .padding(.bottom, 6)
        .transaction { if reduceMotion { $0.disablesAnimations = true; $0.animation = nil } }
    }
}

// MARK: - Empty State

struct PortEmptyStateView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.fill")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
                .rotationEffect(.degrees(rotation))
            Text("No dev servers detected")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
            Text("Start a dev server to see it here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .task(id: reduceMotion) {
            guard !reduceMotion else { rotation = 0; return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    rotation += 360
                }
            }
        }
    }
}

// MARK: - Scanning State

struct PortScanningStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Scanning ports…")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Error State

struct PortErrorStateView: View {
    @Environment(PortStore.self) private var store
    let error: ScanError

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text("Scan failed")
                .font(.callout.bold())
                .foregroundStyle(.secondary)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Button("Retry") { store.refresh() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: - Port Row

struct PortRow: View {
    @Environment(DevelopmentServices.self) private var services
    let entry: ActivePort
    let showTopDivider: Bool
    var databases: [ActivePort] = []
    @Environment(PortStore.self) private var store
    @State private var isHovered = false
    @FocusState private var actionsFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showTopDivider {
                Divider()
                    .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ServiceRowTitle(title: entry.projectName,
                                    marker: .status(store.isStale ? .orange : .green))

                    if let ownerLabel = entry.ownerLabel {
                        Text(ownerLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let url = services.routes[entry.port]?.first {
                        Text(url.host() ?? url.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(url.absoluteString)
                    }
                    Spacer(minLength: 0)

                    HStack(spacing: 2) {
                        if !entry.canOpenInBrowser {
                            RowActionButton(title: "Copy Address", systemImage: "doc.on.doc") {
                                PortStore.copyToClipboard("localhost:\(entry.port)")
                            }
                        } else {
                            RowActionButton(title: "Kill Server", systemImage: "stop.fill", destructive: true) {
                                Task { await store.killProcess(entry) }
                            }
                            .disabled(!canKill)
                            .help(entry.terminationRestriction ?? "Kill Server")
                            if let urls = services.routes[entry.port], let url = urls.first {
                                if urls.count == 1 {
                                    RowActionButton(title: "Open LocalCan — " + url.absoluteString, systemImage: "network") {
                                        NSWorkspace.shared.open(url)
                                    }
                                } else {
                                    Menu {
                                        ForEach(urls, id: \.self) { url in
                                            Button(url.absoluteString) { NSWorkspace.shared.open(url) }
                                        }
                                    } label: {
                                        Label("Open LocalCan", systemImage: "network")
                                            .labelStyle(.iconOnly)
                                            .font(.caption)
                                            .frame(width: 12, height: 14)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                    }
                                    .menuStyle(.borderlessButton)
                                    .menuIndicator(.hidden)
                                    .buttonStyle(RowButtonStyle(destructive: false))
                                    .fixedSize()
                                    .help("Open LocalCan")
                                }
                            }
                            RowActionButton(title: "Open localhost", systemImage: "arrow.up.forward.square") {
                                NSWorkspace.shared.open(entry.url)
                            }
                        }
                    }
                    .focused($actionsFocused)
                    .modifier(RowActionReveal(isVisible: isHovered || actionsFocused || voiceOverEnabled))
                }

                PortServiceMetaRow(
                    symbolName: "network",
                    title: entry.branch,
                    startTime: entry.startTime,
                    port: entry.port
                )

                ForEach(databases) { database in
                    PortDatabaseRow(entry: database)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if entry.canOpenInBrowser {
                ForEach(services.routes[entry.port] ?? [], id: \.self) { url in
                    Button("Copy " + url.absoluteString) { PortStore.copyToClipboard(url.absoluteString) }
                }
                Button("Copy localhost URL") {
                    PortStore.copyToClipboard(entry.url.absoluteString)
                }
            } else {
                Button("Copy Address") { PortStore.copyToClipboard("localhost:\(entry.port)") }
            }
            Button("Copy Port") { PortStore.copyToClipboard(String(entry.port)) }
            if entry.canOpenInBrowser {
                Divider()
                Button("Open in Browser") { NSWorkspace.shared.open(entry.url) }
                Divider()
                Button("Kill Server", role: .destructive) { Task { await store.killProcess(entry) } }
                    .disabled(!canKill)
            }
        }
    }

    private var canKill: Bool {
        entry.canTerminate && !store.isStale && !store.terminatingPIDs.contains(entry.pid)
    }
}

private struct PortExitEffect: ViewModifier {
    var hidden: Bool
    func body(content: Content) -> some View {
        content.blur(radius: hidden ? 8 : 0).opacity(hidden ? 0 : 1).offset(x: hidden ? 340 : 0)
    }
}

// MARK: - Hover Button

struct HoverButton: View {
    let label: String
    let role: ButtonRole?
    let action: () -> Void

    init(_ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .buttonStyle(RowButtonStyle(destructive: role == .destructive))
    }
}

// MARK: - Row Button Style

struct RowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let destructive: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Capsule().fill(backgroundColor(configuration)))
            .foregroundStyle(foregroundColor(configuration))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.92 : isHovered ? 1.04 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(_ c: ButtonStyleConfiguration) -> Color {
        if destructive { return isHovered ? .red.opacity(0.15) : .clear }
        return isHovered ? .primary.opacity(0.1) : .primary.opacity(0.05)
    }

    private func foregroundColor(_ c: ButtonStyleConfiguration) -> Color {
        if destructive { return isHovered ? .red : .secondary }
        return .primary
    }
}

// MARK: - Floating Tooltip

@MainActor
final class FloatingTooltipPanel {
    static let shared = FloatingTooltipPanel()
    private var panel: NSPanel?
    func show(text: String, below anchorFrame: CGRect) {
        present(text: text, below: anchorFrame)
    }

    func hide() {
        panel?.orderOut(nil)
        panel?.alphaValue = 0
    }

    private func present(text: String, below anchorFrame: CGRect) {
        let hosting = NSHostingView(rootView:
            Text(text)
                .font(.caption2)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(.white.opacity(0.96))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.black.opacity(0.82))
                )
                .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
        )
        hosting.frame.size = hosting.fittingSize
        let size = hosting.fittingSize

        if panel == nil {
            let p = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: true
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.level = .popUpMenu
            p.hasShadow = false
            p.ignoresMouseEvents = true
            panel = p
        }

        panel?.contentView = hosting
        panel?.setContentSize(size)
        panel?.setFrameOrigin(NSPoint(
            x: anchorFrame.midX - size.width / 2,
            y: anchorFrame.minY - size.height - 4
        ))

        panel?.alphaValue = 1
        panel?.orderFront(nil)
    }
}

struct FloatingTooltipAnchor: NSViewRepresentable {
    let text: String?
    let isVisible: Bool

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isVisible, let text, !text.isEmpty, let window = nsView.window {
            let windowRect = nsView.convert(nsView.bounds, to: nil)
            let screenRect = window.convertToScreen(windowRect)
            FloatingTooltipPanel.shared.show(text: text, below: screenRect)
        } else {
            FloatingTooltipPanel.shared.hide()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        FloatingTooltipPanel.shared.hide()
    }
}

// MARK: - Helpers

func formatUptime(from start: Date, now: Date = Date()) -> String {
    let s = Int(now.timeIntervalSince(start))
    if s < 60 { return "<1m" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    let h = m / 60
    if h < 24 { return "\(h)h \(m % 60)m" }
    return "\(h / 24)d \(h % 24)h"
}
