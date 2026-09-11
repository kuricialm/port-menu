import SwiftUI

struct SimulatorSectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DevelopmentServices.self) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuSectionHeader("Simulators")
            if let error = services.simulatorError {
                Text(error)
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
            }
            ForEach(Array(services.simulators.enumerated()), id: \.element.id) { index, device in
                if index > 0 { Divider().padding(.horizontal, 16) }
                SimulatorRow(device: device)
            }
        }
        .padding(.bottom, 6)
        .transaction { if reduceMotion { $0.disablesAnimations = true; $0.animation = nil } }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SimulatorRow: View {
    var device: RunningSimulator
    @Environment(DevelopmentServices.self) private var services
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var isHovered = false
    @FocusState private var actionsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(.green).frame(width: 6, height: 6).offset(y: -1)
                    .accessibilityHidden(true)
                Text(device.appNames.isEmpty ? device.name : device.appNames.joined(separator: ", "))
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    RowActionButton(title: "Shut Down " + device.name, systemImage: "stop.fill", destructive: true) {
                        services.perform(device, shutdown: true)
                    }
                    RowActionButton(title: device.isHostedByBitrig ? "Open Bitrig" : "Show Simulator",
                                    systemImage: "arrow.up.forward.square") {
                        services.perform(device, shutdown: false)
                    }
                }
                .disabled(services.busy.contains(device.id))
                .focused($actionsFocused)
                .modifier(RowActionReveal(isVisible: isHovered || actionsFocused || voiceOverEnabled))
            }
            PortServiceMetaRow(
                symbolName: device.deviceSymbolName,
                title: device.name + " • " + device.runtime,
                startTime: device.startTime
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(device.isHostedByBitrig ? "Open Bitrig" : "Show Simulator", systemImage: "arrow.up.forward.square") { services.perform(device, shutdown: false) }
            Button("Shut Down", systemImage: "stop.fill", role: .destructive) { services.perform(device, shutdown: true) }
        }
        .disabled(services.busy.contains(device.id))
    }

}
