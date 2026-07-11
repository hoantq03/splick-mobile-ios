import WidgetKit
import SwiftUI
import SplickWidgetKit

struct FriendStreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetStreakSnapshot?
}

struct FriendStreakProvider: TimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> FriendStreakEntry {
        FriendStreakEntry(
            date: .now,
            snapshot: WidgetStreakSnapshot(currentStreak: 7, hasTodayPhoto: false)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendStreakEntry) -> Void) {
        completion(FriendStreakEntry(date: .now, snapshot: cache.loadStreak()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendStreakEntry>) -> Void) {
        let entry = FriendStreakEntry(date: .now, snapshot: cache.loadStreak())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct FriendStreakWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FriendStreakEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            accessoryCircularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetTierHeader("Streak")
                    Spacer(minLength: 0)
                    WidgetAccentGroup {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("🔥")
                            WidgetMetricText(
                                text: "\(snapshot.currentStreak)",
                                color: WidgetColors.warning
                            )
                        }
                    }
                    Text(streakCaption(for: snapshot))
                        .font(.caption)
                        .foregroundStyle(snapshot.hasTodayPhoto ? .secondary : WidgetColors.error)
                }
                .padding()
            } else {
                WidgetEmptyStateView("Mở Splick để xem streak")
                    .padding()
            }
        }
        .widgetLegacyCardBackground()
    }

    private var mediumView: some View {
        ZStack {
            mediumBackground
            if let snapshot = entry.snapshot {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetTierHeader("Streak ảnh")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("🔥")
                            Text("\(snapshot.currentStreak) ngày")
                                .font(.title.weight(.bold))
                        }
                        Text(streakCaption(for: snapshot))
                            .font(.subheadline)
                            .foregroundStyle(snapshot.hasTodayPhoto ? .secondary : WidgetColors.error)
                    }
                    Spacer(minLength: 0)
                    Link(destination: URL(string: "splick://capture")!) {
                        WidgetCaptureChip()
                    }
                }
                .padding()
            } else {
                WidgetEmptyStateView("Chưa có streak")
                    .padding()
            }
        }
        .widgetLegacyCardBackground()
    }

    @ViewBuilder
    private var mediumBackground: some View {
        switch WidgetOSTier.current {
        case .legacy:
            ContainerRelativeShape()
                .fill(
                    LinearGradient(
                        colors: [WidgetColors.warning.opacity(0.15), Color(.secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .modern, .vibrant:
            LinearGradient(
                colors: [WidgetColors.warning.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .liquidGlass:
            Color.clear
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let streak = entry.snapshot?.currentStreak {
                VStack(spacing: 0) {
                    Text("🔥")
                        .font(.caption2)
                    Text("\(streak)")
                        .font(.caption.weight(.bold))
                }
            } else {
                Image(systemName: "flame")
            }
        }
    }

    private func streakCaption(for snapshot: WidgetStreakSnapshot) -> String {
        if snapshot.currentStreak == 0 {
            return "Bắt đầu streak hôm nay!"
        }
        if snapshot.hasTodayPhoto {
            return "Đã post hôm nay — giữ lửa nhé!"
        }
        return "Chụp ảnh hôm nay để giữ streak!"
    }
}

struct FriendStreakWidget: Widget {
    let kind = WidgetKind.friendStreak

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FriendStreakProvider()) { entry in
            FriendStreakWidgetEntryView(entry: entry)
                .widgetSplickContainerBackground()
        }
        .configurationDisplayName("Streak ảnh")
        .description("Nhắc giữ streak đăng ảnh mỗi ngày.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}
