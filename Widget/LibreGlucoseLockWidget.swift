import SwiftUI
import WidgetKit

@main
struct LibreGlucoseLockWidget: Widget {
    let kind = SharedContainer.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GlucoseTimelineProvider()) { entry in
            GlucoseWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        }
        .configurationDisplayName("Libre Glucose")
        .description("Shows the latest glucose reading and its timestamp.")
        .supportedFamilies([.accessoryRectangular])
    }
}
