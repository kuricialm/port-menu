import SwiftUI

/// Captures the actual MenuBarExtra window without relying on private classes
/// or searching NSApp.windows (which also contains Sparkle's windows).
struct UpdateMenuWindowReader: NSViewRepresentable {
    var presentation: UpdatePresentation

    func makeNSView(context: Context) -> WindowReferenceView {
        WindowReferenceView(presentation: presentation)
    }

    func updateNSView(_ nsView: WindowReferenceView, context: Context) {
        nsView.presentation = presentation
        if let window = nsView.window { presentation.menuWindow = window }
    }

    final class WindowReferenceView: NSView {
        weak var presentation: UpdatePresentation?

        init(presentation: UpdatePresentation) {
            self.presentation = presentation
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { presentation?.menuWindow = window }
        }
    }
}
