import SwiftUI

/// A subordinate service keeps its own address and uptime without repeating the project title.
struct PortDatabaseRow: View {
    var entry: ActivePort
    @State private var isHovered = false
    @FocusState private var actionFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "cylinder")
                .font(.system(size: 10, weight: .medium))
                .frame(width: 6, height: 6)
                .offset(y: -1)
                .accessibilityHidden(true)

            Text(entry.ownerLabel ?? entry.projectName)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(":\(String(entry.port))")
                .fontDesign(.monospaced)
                .foregroundStyle(.tertiary)

            if let start = entry.startTime {
                UptimeText(start: start)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            RowActionButton(title: "Copy Database Address", systemImage: "doc.on.doc") {
                PortStore.copyToClipboard("localhost:\(entry.port)")
            }
            .focused($actionFocused)
            .modifier(RowActionReveal(isVisible: isHovered || actionFocused || voiceOverEnabled))
        }
        .font(.caption)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Address") { PortStore.copyToClipboard("localhost:\(entry.port)") }
            Button("Copy Port") { PortStore.copyToClipboard(String(entry.port)) }
        }
    }
}
