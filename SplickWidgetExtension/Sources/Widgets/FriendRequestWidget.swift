import WidgetKit
import SwiftUI
import SplickWidgetKit

struct FriendRequestEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetFriendRequestsSnapshot?
}

struct FriendRequestProvider: TimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> FriendRequestEntry {
        FriendRequestEntry(
            date: .now,
            snapshot: WidgetFriendRequestsSnapshot(
                pendingCount: 2,
                requests: [
                    WidgetFriendRequestPreview(
                        id: UUID(),
                        requesterName: "Lan",
                        requesterUsername: "lan_nguyen",
                        avatarURL: nil,
                        createdAt: .now
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendRequestEntry) -> Void) {
        completion(FriendRequestEntry(date: .now, snapshot: cache.loadFriendRequests()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendRequestEntry>) -> Void) {
        let entry = FriendRequestEntry(date: .now, snapshot: cache.loadFriendRequests())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct FriendRequestWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FriendRequestEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            ContainerRelativeShape().fill(Color(.systemBackground))
            if let snapshot = entry.snapshot, snapshot.pendingCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetBrandHeader("Lời mời kết bạn")
                    Spacer(minLength: 0)
                    Text("\(snapshot.pendingCount)")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(WidgetColors.primaryStart)
                    if let latest = snapshot.requests.first {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(WidgetColors.brandGradient)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text(String(latest.requesterName.prefix(1)).uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            Text(latest.requesterName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                }
                .padding()
            } else {
                WidgetEmptyStateView("Không có lời mời mới")
            }
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let count = entry.snapshot?.pendingCount, count > 0 {
                Text("\(count)")
                    .font(.headline.weight(.bold))
            } else {
                Image(systemName: "person.badge.plus")
            }
        }
    }
}

struct FriendRequestWidget: Widget {
    let kind = WidgetKind.friendRequest

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FriendRequestProvider()) { entry in
            FriendRequestWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Lời mời kết bạn")
        .description("Xem nhanh lời mời kết bạn đang chờ.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}
