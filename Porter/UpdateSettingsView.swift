import Sparkle
import SwiftUI

struct UpdateSettingsView: View {
    var updater: SPUUpdater
    @State private var checksAutomatically = false
    @State private var installsAutomatically = false

    var body: some View {
        Toggle("Check for Updates Automatically", isOn: Binding(
            get: { checksAutomatically },
            set: { updater.automaticallyChecksForUpdates = $0 }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .onReceive(updater.publisher(for: \.automaticallyChecksForUpdates)) { checksAutomatically = $0 }

        Toggle("Install Updates Automatically", isOn: Binding(
            get: { installsAutomatically },
            set: { updater.automaticallyDownloadsUpdates = $0 }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .disabled(!checksAutomatically)
        .onReceive(updater.publisher(for: \.automaticallyDownloadsUpdates)) { installsAutomatically = $0 }
    }
}
