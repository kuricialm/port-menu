import SwiftUI

/// Project title with the live-status marker.
struct ServiceRowTitle: View {
    var title: String
    var marker: Marker

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle().fill(marker.color)
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

        var color: Color {
            switch self {
            case .status(let color): color
            }
        }
    }
}
