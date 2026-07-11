import WidgetKit
import SwiftUI
import SplickWidgetKit

struct UnreadMessagesEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetMessagingInboxSnapshot?
}

struct UnreadMessagesProvider: TimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> UnreadMessagesEntry {
        UnreadMessagesEntry(
            date: .now,
            snapshot: WidgetMessagingInboxSnapshot(
                totalUnreadCount: 3,
                conversations: [
                    WidgetConversationPreview(
                        id: UUID(),
                        displayTitle: "Minh",
                        previewText: "Hey bạn ơi!",
                        unreadCount: 2,
                        avatarURL: nil,
                        updatedAt: .now
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UnreadMessagesEntry) -> Void) {
        completion(UnreadMessagesEntry(date: .now, snapshot: cache.loadMessagingInbox()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UnreadMessagesEntry>) -> Void) {
        let entry = UnreadMessagesEntry(date: .now, snapshot: cache.loadMessagingInbox())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct UnreadMessagesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UnreadMessagesEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            if let snapshot = entry.snapshot, snapshot.totalUnreadCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetTierHeader("Tin nhắn")
                    Spacer(minLength: 0)
                    WidgetAccentGroup {
                        WidgetMetricText(
                            text: "\(snapshot.totalUnreadCount)",
                            color: WidgetColors.primaryStart
                        )
                    }
                    if let latest = snapshot.conversations.first {
                        Text(latest.displayTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(latest.previewText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding()
            } else {
                WidgetEmptyStateView("Không có tin nhắn mới")
                    .padding()
            }
        }
        .widgetLegacyCardBackground()
    }

    private var mediumView: some View {
        ZStack {
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        WidgetTierHeader("Tin nhắn")
                        Spacer()
                        if snapshot.totalUnreadCount > 0 {
                            WidgetAccentGroup {
                                Text("\(snapshot.totalUnreadCount)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(WidgetColors.primaryStart.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    ForEach(Array(snapshot.conversations.prefix(2).enumerated()), id: \.offset) { _, conversation in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(WidgetColors.brandGradient)
                                .frame(width: 34, height: 34)
                                .overlay {
                                    Text(String(conversation.displayTitle.prefix(1)).uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conversation.displayTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(conversation.previewText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                            if conversation.unreadCount > 0 {
                                Text("\(conversation.unreadCount)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(Circle().fill(WidgetColors.primaryStart))
                            }
                        }
                    }
                    if snapshot.conversations.isEmpty {
                        WidgetEmptyStateView("Hộp thư trống")
                    }
                }
                .padding()
            } else {
                WidgetEmptyStateView("Mở Splick để đồng bộ")
                    .padding()
            }
        }
        .widgetLegacyCardBackground()
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let count = entry.snapshot?.totalUnreadCount, count > 0 {
                Text("\(count)")
                    .font(.headline.weight(.bold))
            } else {
                Image(systemName: "message")
            }
        }
    }

    @ViewBuilder
    private var accessoryRectangularView: some View {
        if let conversation = entry.snapshot?.conversations.first {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(conversation.displayTitle): \(conversation.previewText)")
                    .font(.caption)
                    .lineLimit(2)
            }
        } else {
            Text("Không có tin nhắn mới")
        }
    }
}

struct UnreadMessagesWidget: Widget {
    let kind = WidgetKind.unreadMessages

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UnreadMessagesProvider()) { entry in
            UnreadMessagesWidgetEntryView(entry: entry)
                .widgetSplickContainerBackground()
        }
        .configurationDisplayName("Tin nhắn chưa đọc")
        .description("Xem nhanh tin nhắn mới từ bạn bè.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}
