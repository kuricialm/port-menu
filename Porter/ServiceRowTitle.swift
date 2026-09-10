import SwiftUI

/// Shared title geometry keeps project and database rows visually identical.
struct ServiceRowTitle: View {
    var title: String
    var marker: Marker

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Group {
                switch marker {
                case .status(let color):
                    Circle().fill(color)
                case .database:
                    Image(systemName: "cylinder")
                        .resizable()
                        .scaledToFit()
                }
            }
            .frame(width: 6, height: 6)
            .offset(y: -1)
            .accessibilityHidden(true)

            Text(title)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    enum Marker {
        case status(Color)
        case database
    }
}
