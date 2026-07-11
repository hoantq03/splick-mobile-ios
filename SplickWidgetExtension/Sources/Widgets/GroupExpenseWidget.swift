import SwiftUI
import WidgetKit
import SplickWidgetKit

struct GroupExpenseWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GroupExpenseEntry
    var emptyMessage: String = "Mở Splick để đồng bộ nhóm"

    var body: some View {
        switch family {
        case .systemLarge:
            largeView
        case .accessoryRectangular:
            rectangularView
        default:
            mediumView
        }
    }

    private var mediumView: some View {
        ZStack {
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetTierHeader("Chi tiêu nhóm")
                    Text(snapshot.groupName)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)
                    HStack {
                        WidgetMetricText(text: snapshot.totalAmount, color: .primary)
                        Spacer()
                        Text("\(snapshot.settledPercentage)% settled")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetColors.success)
                    }
                    ProgressView(value: Double(snapshot.settledPercentage), total: 100)
                        .tint(WidgetColors.success)
                }
                .padding()
            } else {
                WidgetEmptyStateView(emptyMessage)
                    .padding()
            }
        }
        .widgetLegacyCardBackground()
    }

    private var largeView: some View {
        ZStack {
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetTierHeader("Nhóm • \(snapshot.groupName)")
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổng")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            WidgetMetricText(text: snapshot.totalAmount, color: .primary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Đã settle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(snapshot.settledPercentage)%")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(WidgetColors.success)
                        }
                    }
                    Divider()
                    ForEach(Array(snapshot.memberBalances.prefix(6).enumerated()), id: \.offset) { _, member in
                        HStack {
                            Text(member.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text(member.isOwed ? "+\(member.amount)" : "-\(member.amount)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(member.isOwed ? WidgetColors.success : WidgetColors.error)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding()
            } else {
                WidgetEmptyStateView(emptyMessage)
                    .padding()
            }
        }
        .widgetLegacyCardBackground()
    }

    @ViewBuilder
    private var rectangularView: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.groupName) • \(snapshot.totalAmount)")
                    .font(.caption)
                    .lineLimit(1)
                Text("\(snapshot.settledPercentage)% đã settle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Splick nhóm")
        }
    }
}

struct GroupExpenseWidget: Widget {
    let kind = WidgetKind.groupExpense

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GroupExpenseStaticProvider()) { entry in
            GroupExpenseWidgetEntryView(
                entry: GroupExpenseEntry(
                    date: entry.date,
                    groupId: entry.snapshot?.groupId,
                    snapshot: entry.snapshot
                )
            )
            .widgetSplickContainerBackground()
        }
        .configurationDisplayName("Chi tiêu nhóm")
        .description("Theo dõi chi tiêu nhóm (nhóm đầu tiên trong cache).")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}

/// iOS 17+ configurable variant — kept for when widget extension min target moves to 17.
@available(iOSApplicationExtension 17.0, *)
struct GroupExpenseConfigurableWidget: Widget {
    let kind = WidgetKind.groupExpense

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: GroupExpenseIntent.self,
            provider: GroupExpenseProvider()
        ) { entry in
            GroupExpenseWidgetEntryView(
                entry: entry,
                emptyMessage: "Chọn nhóm trong cài đặt widget"
            )
            .widgetSplickContainerBackground()
        }
        .configurationDisplayName("Chi tiêu nhóm")
        .description("Theo dõi chi tiêu của một nhóm cụ thể.")
        .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
    }
}
