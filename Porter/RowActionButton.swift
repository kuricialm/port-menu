import SwiftUI

/// Compact actions retain the author's capsule styling and press/hover springs.
struct RowActionButton: View {
    var title: String
    var systemImage: String
    var destructive = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.caption)
                .frame(width: 12, height: 14)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .contentShape(Capsule())
        }
        .buttonStyle(RowButtonStyle(destructive: destructive))
        .help(title)
    }
}

struct RowActionReveal: ViewModifier {
    var isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion || isVisible ? 1 : 0.85, anchor: .trailing)
            .offset(x: reduceMotion || isVisible ? 0 : 6)
            .animation(.smooth(duration: 0.15), value: isVisible)
    }
}
