import SwiftUI

/// Caption line shared by ports, grouped databases, and simulator devices.
struct PortServiceMetaRow: View {
    var symbolName: String
    var title: String
    var startTime: Date?
    var port: UInt16? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .accessibilityHidden(true)

            if !title.isEmpty {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let start = startTime {
                if !title.isEmpty { Text("·").foregroundStyle(.tertiary) }
                UptimeText(start: start)
                    .foregroundStyle(.tertiary)
            }

            if let port {
                Text(":\(String(port))")
                    .fontDesign(.monospaced)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
