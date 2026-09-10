import SwiftUI

struct UptimeText: View {
    var start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 60)) { context in
            Text(formatUptime(from: start, now: context.date))
                .accessibilityLabel("Running for " + formatUptime(from: start, now: context.date))
        }
        .help("Started " + start.formatted(date: .abbreviated, time: .standard))
    }
}
