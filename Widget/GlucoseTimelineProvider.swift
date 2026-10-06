import LibreGlucoseCore
import WidgetKit

struct GlucoseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlucoseWidgetEntry {
        GlucoseWidgetEntry(date: .now, viewModel: Self.previewModel)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlucoseWidgetEntry) -> Void) {
        if context.isPreview {
            completion(GlucoseWidgetEntry(date: .now, viewModel: Self.previewModel))
            return
        }

        let completion = SendableCompletion(completion)
        Task {
            let now = Date()
            let model: WidgetReadingViewModel
            do {
                let cache = try SharedContainer.makeReadingCache()
                if let reading = try await cache.load() {
                    model = .make(outcome: .cached(reading), fallback: nil, now: now)
                } else {
                    model = .reconnect
                }
            } catch {
                model = .unavailable
            }
            completion(GlucoseWidgetEntry(date: now, viewModel: model))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlucoseWidgetEntry>) -> Void) {
        let completion = SendableCompletion(completion)
        Task {
            let now = Date()
            let model: WidgetReadingViewModel
            do {
                let cache = try SharedContainer.makeReadingCache()
                let fallback = try? await cache.load()
                let credentialStore = try SharedContainer.makeCredentialStore()
                let coordinator = ReadingCoordinator(
                    dataSource: LibreLinkUpDataSource(),
                    credentialStore: credentialStore,
                    readingCache: cache
                )
                let outcome = await coordinator.refresh()
                model = .make(outcome: outcome, fallback: fallback, now: now)
            } catch {
                model = .unavailable
            }

            let entry = GlucoseWidgetEntry(date: now, viewModel: model)
            let nextRequest = Calendar.current.date(byAdding: .minute, value: 15, to: now)
                ?? now.addingTimeInterval(15 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRequest)))
        }
    }

    static var previewModel: WidgetReadingViewModel {
        .reading(
            value: "123",
            unit: "mg/dL",
            trend: "→",
            detail: "14:32 · 8 min ago",
            freshness: .fresh
        )
    }
}

private final class SendableCompletion<Value>: @unchecked Sendable {
    private let completion: (Value) -> Void

    init(_ completion: @escaping (Value) -> Void) {
        self.completion = completion
    }

    func callAsFunction(_ value: Value) {
        completion(value)
    }
}
