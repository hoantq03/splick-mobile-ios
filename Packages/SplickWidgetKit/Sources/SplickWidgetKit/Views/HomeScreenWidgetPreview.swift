import SwiftUI

/// In-app Home Screen widget mock (systemSmall scale) for settings.
public struct HomeScreenWidgetPreview: View {
    public let widget: HomeScreenWidget
    public var title: String

    public init(widget: HomeScreenWidget, title: String) {
        self.widget = widget
        self.title = title
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
            content
                .padding(12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch widget {
        case .expenseSummary:
            metricPreview(
                metric: "+150,000₫",
                metricColor: WidgetColors.success,
                caption: "Nợ 2 • Được nợ 1"
            )
        case .unreadMessages:
            metricPreview(
                metric: "3",
                metricColor: WidgetColors.primaryStart,
                caption: "Minh"
            )
        case .latestFriendPhoto:
            photoPreview(name: "Bạn bè")
        case .friendStreak:
            metricPreview(
                metric: "🔥 7",
                metricColor: WidgetColors.warning,
                caption: "Đã post hôm nay"
            )
        case .quickCapture:
            capturePreview
        case .friendRequest:
            metricPreview(
                metric: "2",
                metricColor: WidgetColors.primaryStart,
                caption: "Lan"
            )
        case .groupExpense:
            groupPreview
        }
    }

    private func metricPreview(metric: String, metricColor: Color, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            Text(metric)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(metricColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: widget.systemImage)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(WidgetColors.primaryStart)
    }

    private var capturePreview: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 28, weight: .semibold))
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WidgetColors.brandGradient)
        )
    }

    private func photoPreview(name: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            WidgetColors.brandGradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var groupPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Text("Nhóm Trip")
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
            Text("2,400,000₫")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            ProgressView(value: 0.62)
                .tint(WidgetColors.success)
            Text("62%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetColors.success)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
