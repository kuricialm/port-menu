import SwiftUI

struct SimulatorSectionView: View {
    @Environment(DevelopmentServices.self) private var services

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Simulators")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let error = services.simulatorError {
                Text(error).font(.caption).foregroundStyle(.secondary)
            } else if services.simulators.isEmpty {
                Text("No running simulators")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            ForEach(services.simulators) { device in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "app.dashed")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(device.appNames.isEmpty ? device.name : device.appNames.joined(separator: ", "))
                            .font(.body.weight(.medium))
                            .lineLimit(2)
                        Spacer()
                        HoverButton("Shut Down", role: .destructive) { services.perform(device, shutdown: true) }
                            .accessibilityLabel("Shut down " + device.name)
                        HoverButton("Show") { services.perform(device, shutdown: false) }
                            .accessibilityLabel("Show " + device.name)
                    }
                    Text(device.name + " • " + device.runtime)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .disabled(services.busy.contains(device.id))
                if device.id != services.simulators.last?.id { Divider() }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
