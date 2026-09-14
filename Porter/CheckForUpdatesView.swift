import Sparkle
import SwiftUI

struct CheckForUpdatesView: View {
    var updater: SPUUpdater
    @Environment(UpdatePresentation.self) private var presentation
    @Environment(\.dismiss) private var dismiss
    @State private var canCheckForUpdates = false
    @State private var sessionInProgress = false

    var body: some View {
        Button(ManualUpdateAction(canCheckForUpdates: canCheckForUpdates,
                                  sessionInProgress: sessionInProgress).title) {
            dismiss()
            presentation.checkForUpdates(using: updater)
        }
        .disabled(!canCheckForUpdates)
        .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheckForUpdates = $0 }
        .onReceive(updater.publisher(for: \.sessionInProgress)) { sessionInProgress = $0 }
    }
}
