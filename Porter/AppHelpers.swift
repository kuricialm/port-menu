import AppKit
import os

@MainActor
func moveToApplicationsIfNeeded() {
    // Test hosts must not relocate or terminate during XCTest bootstrap.
    guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
          NSClassFromString("XCTestCase") == nil else { return }
    let sourceURL = Bundle.main.bundleURL
    let sourcePath = sourceURL.path
    let destinationURL = URL(filePath: "/Applications/Port Menu.app")

    guard !sourcePath.hasPrefix("/Applications/"),
          !sourcePath.contains("DerivedData"),
          !sourcePath.hasPrefix("/tmp/"),
          !sourcePath.hasPrefix("/private/tmp/"),
          sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else { return }

    let alert = NSAlert()
    alert.messageText = "Install to Applications Folder?"
    alert.informativeText = "Port Menu works best when run from the Applications folder. Your original copy will be kept."
    alert.addButton(withTitle: "Install to Applications")
    alert.addButton(withTitle: "Not Now")
    alert.alertStyle = .informational
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    if FileManager.default.fileExists(atPath: destinationURL.path) {
        let replaceAlert = NSAlert()
        replaceAlert.messageText = "Replace Existing Application?"
        replaceAlert.informativeText = "A copy of Port Menu already exists in Applications. Replace it with this version?"
        replaceAlert.addButton(withTitle: "Replace")
        replaceAlert.addButton(withTitle: "Cancel")
        replaceAlert.alertStyle = .warning
        guard replaceAlert.runModal() == .alertFirstButtonReturn else { return }
    }

    // Copy the running bundle itself, including when macOS has translocated it.
    // A matching filename elsewhere is not proof that it is this app/version.
    Task { @MainActor in
        do {
            let retainedBackup = try await ApplicationInstaller().install(from: sourceURL, to: destinationURL)
            if let retainedBackup {
                Log.lifecycle.notice("Installed app; previous copy retained at \(retainedBackup.path, privacy: .public)")
            }
            NSApp.terminate(nil)
        } catch {
            Log.lifecycle.error("Failed to install app in Applications: \(error.localizedDescription)")
            let errorAlert = NSAlert()
            errorAlert.messageText = "Couldn't Install Port Menu"
            errorAlert.informativeText = "Your original copy is still available.\n\n\(error.localizedDescription)"
            errorAlert.addButton(withTitle: "OK")
            errorAlert.alertStyle = .warning
            errorAlert.runModal()
        }
    }
}
