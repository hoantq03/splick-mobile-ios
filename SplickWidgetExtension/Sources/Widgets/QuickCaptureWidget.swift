import WidgetKit
import SwiftUI
import SplickWidgetKit

struct QuickCaptureEntry: TimelineEntry {
    let date: Date
}

struct QuickCaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickCaptureEntry) -> Void) {
        completion(QuickCaptureEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCaptureEntry>) -> Void) {
        let entry = QuickCaptureEntry(date: .now)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct QuickCaptureWidgetEntryView: View {
    let entry: QuickCaptureEntry

    var body: some View {
        Link(destination: URL(string: "splick://capture")!) {
            ZStack {
                ContainerRelativeShape()
                    .fill(WidgetColors.brandGradient)
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 34, weight: .semibold))
                    Text("Chia sẻ ngay")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
            }
        }
    }
}

struct QuickCaptureWidget: Widget {
    let kind = WidgetKind.quickCapture

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetColors.brandGradient
                }
        }
        .configurationDisplayName("Chụp nhanh")
        .description("Mở thẳng camera Splick từ màn hình chính.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
