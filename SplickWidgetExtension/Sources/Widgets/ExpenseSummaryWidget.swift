import WidgetKit
import SwiftUI
import SplickWidgetKit

struct ExpenseSummaryEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetExpenseSummarySnapshot?
}

struct ExpenseSummaryProvider: TimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> ExpenseSummaryEntry {
        ExpenseSummaryEntry(
            date: .now,
            snapshot: WidgetExpenseSummarySnapshot(
                netAmount: "+150,000₫",
                currency: "VND",
                totalOwing: "350,000₫",
                totalOwed: "500,000₫",
                owingPeopleCount: 2,
                owedPeopleCount: 1,
                topDebts: [
                    WidgetDebtItem(
                        userId: UUID(),
                        displayName: "Minh",
                        amount: "200,000₫",
                        currency: "VND",
                        isOwed: false
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ExpenseSummaryEntry) -> Void) {
        completion(ExpenseSummaryEntry(date: .now, snapshot: cache.loadExpenseSummary()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ExpenseSummaryEntry>) -> Void) {
        let entry = ExpenseSummaryEntry(date: .now, snapshot: cache.loadExpenseSummary())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct ExpenseSummaryWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ExpenseSummaryEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        case .accessoryInline:
            accessoryInlineView
        default:
            smallView
        }
    }

    private var smallView: some View {
        ZStack {
            ContainerRelativeShape().fill(Color(.systemBackground))
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetBrandHeader("Chi tiêu")
                    Spacer(minLength: 0)
                    Text(snapshot.netAmount)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(netColor(for: snapshot))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(netCaption(for: snapshot))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                WidgetEmptyStateView("Mở Splick để đồng bộ")
            }
        }
    }

    private var mediumView: some View {
        ZStack {
            ContainerRelativeShape().fill(Color(.systemBackground))
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetBrandHeader("Tổng quan nợ")
                    HStack {
                        Text(snapshot.netAmount)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(netColor(for: snapshot))
                        Spacer()
                        Text(netCaption(for: snapshot))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(snapshot.topDebts.prefix(2).enumerated()), id: \.offset) { _, debt in
                        HStack {
                            Text(debt.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(debt.isOwed ? "+\(debt.amount)" : "-\(debt.amount)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(debt.isOwed ? WidgetColors.success : WidgetColors.error)
                        }
                    }
                }
                .padding()
            } else {
                WidgetEmptyStateView("Chưa có dữ liệu chi tiêu")
            }
        }
    }

    private var largeView: some View {
        ZStack {
            ContainerRelativeShape().fill(Color(.systemBackground))
            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    WidgetBrandHeader("Chi tiêu Splick")
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Net")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(snapshot.netAmount)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(netColor(for: snapshot))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Đang nợ \(snapshot.owingPeopleCount)")
                                .font(.caption)
                            Text("Được nợ \(snapshot.owedPeopleCount)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Divider()
                    ForEach(Array(snapshot.topDebts.prefix(5).enumerated()), id: \.offset) { _, debt in
                        HStack {
                            Text(debt.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text(debt.isOwed ? "+\(debt.amount)" : "-\(debt.amount)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(debt.isOwed ? WidgetColors.success : WidgetColors.error)
                        }
                    }
                    Spacer(minLength: 0)
                    Link(destination: URL(string: "splick://expenses")!) {
                        Text("Mở Splick")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(WidgetColors.primaryStart.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            } else {
                WidgetEmptyStateView("Chưa có dữ liệu chi tiêu")
            }
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let snapshot = entry.snapshot {
                VStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                    Text("\(snapshot.owingPeopleCount + snapshot.owedPeopleCount)")
                        .font(.caption2.weight(.bold))
                }
            } else {
                Image(systemName: "dollarsign.circle")
            }
        }
    }

    private var accessoryRectangularView: some View {
        if let snapshot = entry.snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Text("Splick • Chi tiêu")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Nợ \(snapshot.owingPeopleCount) người • \(snapshot.totalOwing)")
                    .font(.caption)
                    .lineLimit(1)
            }
        } else {
            Text("Splick chi tiêu")
        }
    }

    private var accessoryInlineView: some View {
        if let snapshot = entry.snapshot {
            Text("Splick: \(snapshot.netAmount)")
        } else {
            Text("Splick chi tiêu")
        }
    }

    private func netColor(for snapshot: WidgetExpenseSummarySnapshot) -> Color {
        snapshot.netAmount.hasPrefix("+") ? WidgetColors.success : WidgetColors.error
    }

    private func netCaption(for snapshot: WidgetExpenseSummarySnapshot) -> String {
        if snapshot.owingPeopleCount == 0, snapshot.owedPeopleCount == 0 {
            return "Không có khoản nợ"
        }
        return "Nợ \(snapshot.owingPeopleCount) • Được nợ \(snapshot.owedPeopleCount)"
    }
}

struct ExpenseSummaryWidget: Widget {
    let kind = WidgetKind.expenseSummary

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ExpenseSummaryProvider()) { entry in
            ExpenseSummaryWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Tổng quan chi tiêu")
        .description("Theo dõi nợ và được nợ mà không cần mở app.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
