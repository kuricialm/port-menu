import AppKit
import Testing
@testable import Port_Menu

@MainActor
struct UpdatePresentationTests {
    @Test func manualCheckDismissesMenuBeforeActivatingAndInvokingSparkle() {
        let menu = makeWindow()
        defer { menu.close() }
        var activated = false
        var checks = 0
        let presentation = UpdatePresentation {
            #expect(!menu.isVisible)
            activated = true
        }
        menu.contentView = UpdateMenuWindowReader.WindowReferenceView(presentation: presentation)
        #expect(presentation.menuWindow === menu)
        menu.orderFront(nil)
        #expect(menu.isVisible)

        presentation.performCheck(isAvailable: true) {
            #expect(activated)
            #expect(!menu.isVisible)
            checks += 1
        }
        #expect(checks == 1)

        // Closing the menu for an update must not require an app restart.
        menu.orderFront(nil)
        #expect(menu.isVisible)
        presentation.performCheck(isAvailable: true) { checks += 1 }
        #expect(checks == 2)
        #expect(!menu.isVisible)
    }

    @Test func busyUpdaterDoesNotStartADuplicateCheckOrCloseMenu() {
        let menu = makeWindow()
        defer { menu.close() }
        let presentation = UpdatePresentation { Issue.record("Should not activate for an unavailable check") }
        presentation.menuWindow = menu
        menu.orderFront(nil)
        presentation.performCheck(isAvailable: false) { Issue.record("Should not call Sparkle while busy") }
        #expect(menu.isVisible)
    }

    @Test func modalResultDismissesReopenedMenuWithoutClosingTheUpdateWindow() {
        let menu = makeWindow()
        let update = makeWindow()
        defer { menu.close(); update.close() }
        var activations = 0
        let presentation = UpdatePresentation { activations += 1 }
        presentation.menuWindow = menu
        menu.orderFront(nil)
        update.orderFront(nil)
        presentation.standardUserDriverWillShowModalAlert()
        #expect(!menu.isVisible)
        #expect(update.isVisible)
        #expect(activations == 1)
    }

    @Test func appMenuCommandWorksWithoutAnOpenMenuBarPanel() {
        var activated = false
        let presentation = UpdatePresentation { activated = true }
        var checked = false
        presentation.performCheck(isAvailable: true) {
            #expect(activated)
            checked = true
        }
        #expect(checked)
    }

    @Test func buttonDistinguishesBusyExistingAndIdleSessions() {
        #expect(ManualUpdateAction(canCheckForUpdates: false, sessionInProgress: true).title == "Update in Progress…")
        #expect(ManualUpdateAction(canCheckForUpdates: true, sessionInProgress: true).title == "Show Update…")
        #expect(ManualUpdateAction(canCheckForUpdates: true, sessionInProgress: false).title == "Check for Updates…")
        #expect(ManualUpdateAction(canCheckForUpdates: false, sessionInProgress: false).title == "Check for Updates…")
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 60),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
}
