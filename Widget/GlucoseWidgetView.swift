import LibreGlucoseCore
import SwiftUI
import WidgetKit

struct GlucoseWidgetView: View {
    let entry: GlucoseWidgetEntry

    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .widgetURL(URL(string: "libreglucose://open"))
    }

    @ViewBuilder
    private var content: some View {
        switch entry.viewModel {
        case let .reading(value, unit, trend, detail, freshness):
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                        Text(trend)
                            .font(.headline.weight(.bold))
                    }
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(detail)
                    .font(.caption.weight(freshness == .stale ? .semibold : .regular))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Glucose \(value) \(unit), trend \(trend), \(detail)")

        case .reconnect, .unavailable:
            Label(entry.viewModel.message ?? "Reading unavailable", systemImage: "arrow.clockwise.circle")
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Fresh", as: .accessoryRectangular) {
    LibreGlucoseLockWidget()
} timeline: {
    GlucoseWidgetEntry(date: .now, viewModel: GlucoseTimelineProvider.previewModel)
}

#Preview("Delayed", as: .accessoryRectangular) {
    LibreGlucoseLockWidget()
} timeline: {
    GlucoseWidgetEntry(
        date: .now,
        viewModel: .reading(value: "6.8", unit: "mmol/L", trend: "↗", detail: "14:32 · 42 min ago", freshness: .delayed)
    )
}

#Preview("Stale", as: .accessoryRectangular) {
    LibreGlucoseLockWidget()
} timeline: {
    GlucoseWidgetEntry(
        date: .now,
        viewModel: .reading(value: "123", unit: "mg/dL", trend: "→", detail: "STALE · 14:32", freshness: .stale)
    )
}

#Preview("Reconnect", as: .accessoryRectangular) {
    LibreGlucoseLockWidget()
} timeline: {
    GlucoseWidgetEntry(date: .now, viewModel: .reconnect)
}

#Preview("Unavailable", as: .accessoryRectangular) {
    LibreGlucoseLockWidget()
} timeline: {
    GlucoseWidgetEntry(date: .now, viewModel: .unavailable)
}

#Preview("Accessibility size") {
    GlucoseWidgetView(
        entry: GlucoseWidgetEntry(date: .now, viewModel: GlucoseTimelineProvider.previewModel)
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 364, height: 80)
}
