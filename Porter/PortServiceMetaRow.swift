import SwiftUI

/// Caption line shared by a project's HTTP endpoint and any grouped database.
struct PortServiceMetaRow: View {
    var symbolName: String
    var title: String
    var startTime: Date?
    var port: UInt16

    var body: some View {
        HStack(spacing: 6) {
            if !title.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: symbolName)
                        .accessibilityHidden(true)
                    Text(title)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let start = startTime {
                if !title.isEmpty { Text("·").foregroundStyle(.tertiary) }
                UptimeText(start: start)
                    .foregroundStyle(.tertiary)
            }

            Text(":\(String(port))")
                .fontDesign(.monospaced)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
