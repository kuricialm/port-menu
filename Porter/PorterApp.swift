import Sparkle
import SwiftUI

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
    }
}

@main
struct PorterApp: App {
    @State private var store = PortStore.shared
    @State private var services = DevelopmentServices()
    @State private var instance = ApplicationInstanceController.shared
    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate = UpdaterDelegate()

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        let updater = updaterController
        ApplicationInstanceController.shared.start {
            updater.startUpdater()
            moveToApplicationsIfNeeded()
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $instance.isPrimaryInstance) {
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
            .accessibilityLabel("Port Menu, \(store.entries.count) ports and \(services.simulators.count) simulators" + statusDescription)
            .help("\(store.entries.count) ports · \(services.simulators.count) simulators" + statusDescription)
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

    private var statusDescription: String {
        if store.isStale && services.simulatorError != nil { return " · Port data is stale; simulator results may be incomplete" }
        if store.isStale { return " · Ports may be out of date" }
        if services.simulatorError != nil { return " · Simulator results may be incomplete" }
        return " active"
    }

    private var statusColor: Color {
        if store.lastError != nil || services.simulatorError != nil {
            return .orange
        }
        return activeCount == 0 ? .gray : .green
    }
}
