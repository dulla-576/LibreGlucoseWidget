import SwiftUI
import WidgetKit

private struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

private struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

@main
struct LibreGlucoseLockWidget: Widget {
    let kind = "LibreGlucoseLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PlaceholderProvider()) { _ in
            Text("Open app to reconnect")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Libre Glucose")
        .description("Shows the latest glucose reading and its timestamp.")
        .supportedFamilies([.accessoryRectangular])
    }
}
