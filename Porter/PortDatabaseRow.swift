import SwiftUI

/// A subordinate service keeps its own address and uptime without repeating the project title.
struct PortDatabaseRow: View {
    var entry: ActivePort
    @State private var isHovered = false
    @FocusState private var actionFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ServiceRowTitle(title: entry.ownerLabel ?? entry.projectName, marker: .database)
                Spacer(minLength: 0)

                RowActionButton(title: "Copy Database Address", systemImage: "doc.on.doc") {
                    PortStore.copyToClipboard("localhost:\(entry.port)")
                }
                .focused($actionFocused)
                .modifier(RowActionReveal(isVisible: isHovered || actionFocused || voiceOverEnabled))
            }

            HStack(spacing: 6) {
                if let start = entry.startTime {
                    UptimeText(start: start)
                }
                Text(":\(String(entry.port))")
                    .fontDesign(.monospaced)
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Address") { PortStore.copyToClipboard("localhost:\(entry.port)") }
            Button("Copy Port") { PortStore.copyToClipboard(String(entry.port)) }
        }
    }
}
