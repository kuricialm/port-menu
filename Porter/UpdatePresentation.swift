import AppKit
import Observation
import Sparkle

/// Hands focus from the menu-bar panel to Sparkle's existing update UI.
@MainActor @Observable
final class UpdatePresentation: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    @ObservationIgnored weak var menuWindow: NSWindow?
    @ObservationIgnored private var activateApplication: () -> Void

    init(activateApplication: @escaping () -> Void = { NSApplication.shared.activate() }) {
        self.activateApplication = activateApplication
        super.init()
    }

    func checkForUpdates(using updater: SPUUpdater) {
        performCheck(isAvailable: updater.canCheckForUpdates) {
            // Sparkle also uses this to bring an existing update back in focus.
            updater.checkForUpdates()
        }
    }

    func performCheck(isAvailable: Bool, check: () -> Void) {
        guard isAvailable else { return }
        prepareForUpdateWindow()
        check()
    }

    func standardUserDriverWillShowModalAlert() {
        // Sparkle delivers user-driver callbacks on the main thread; its
        // Objective-C protocol does not yet express that actor isolation.
        // Also covers "You're up to date" and failed-check alerts if the menu
        // was reopened while a check was in flight.
        prepareForUpdateWindow()
    }

    private func prepareForUpdateWindow() {
        // Only dismiss the registered menu panel, never Sparkle or app windows.
        menuWindow?.close()
        activateApplication()
    }
}

struct ManualUpdateAction {
    var canCheckForUpdates: Bool
    var sessionInProgress: Bool

    var title: String {
        if sessionInProgress {
            return canCheckForUpdates ? "Show Update…" : "Update in Progress…"
        }
        return "Check for Updates…"
    }
}
