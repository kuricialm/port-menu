import SwiftUI

/// A subordinate service keeps its own address and uptime without repeating the project title.
struct PortDatabaseRow: View {
    var entry: ActivePort
    @State private var isHovered = false
    @FocusState private var actionFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        PortServiceMetaRow(
            symbolName: "cylinder.split.1x2",
            title: entry.ownerLabel ?? entry.projectName,
            startTime: entry.startTime,
            port: entry.port
        )
        .overlay(alignment: .trailing) {
            RowActionButton(title: "Copy Database Address", systemImage: "doc.on.doc") {
                PortStore.copyToClipboard("localhost:\(entry.port)")
            }
            .focused($actionFocused)
            .modifier(RowActionReveal(isVisible: isHovered || actionFocused || voiceOverEnabled))
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Address") { PortStore.copyToClipboard("localhost:\(entry.port)") }
            Button("Copy Port") { PortStore.copyToClipboard(String(entry.port)) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(entry.ownerLabel ?? entry.projectName)
    }
}
