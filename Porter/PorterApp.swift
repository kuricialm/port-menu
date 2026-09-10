import Sparkle
import SwiftUI

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        "https://raw.githubusercontent.com/wieandteduard/port-menu/main/packaging/appcast.xml"
    }
}

@main
struct PorterApp: App {
    @State private var store = PortStore.shared
    @State private var services = DevelopmentServices()
    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate = UpdaterDelegate()

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        moveToApplicationsIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            PortListView(updater: updaterController.updater)
                .environment(store)
                .environment(services)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: activeCount == 0
                      ? "square.fill"
                      : "circle.fill")
                    .font(.system(size: 5.5))
                    .foregroundStyle(statusColor)
                Text(activeCount, format: .number)
                    .fontDesign(.monospaced)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Port Menu, \(store.entries.count) ports and \(services.simulators.count) simulators active")
            .help("\(store.entries.count) ports · \(services.simulators.count) simulators")
            .onAppear { store.ensurePolling() }
            .task {
                await services.poll { store.refreshInterval.rawValue }
            }
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }

    private var activeCount: Int {
        store.entries.count + services.simulators.count
    }

    private var statusColor: Color {
        if (store.lastError != nil || services.simulatorError != nil) && activeCount == 0 {
            return .orange
        }
        return activeCount == 0 ? .gray : .green
    }
}
