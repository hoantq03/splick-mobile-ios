import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct StreakMonthSectionView: View {
    let section: StreakMonthSection
    let onDayTap: (StreakDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(section.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.leading, SplickTheme.Spacing.xxs)

            weekdayLabels

            dayGrid
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.lg)
    }

    private var weekdayLabels: some View {
        HStack(spacing: 4) {
            ForEach(StreakCalendarLayout.weekdaySymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var dayGrid: some View {
        let leadingCount = StreakCalendarLayout.leadingEmptyCellCount(
            year: section.year,
            month: section.month
        )
        let totalCount = leadingCount + section.days.count

        return LazyVGrid(columns: StreakCalendarLayout.gridColumns, spacing: 4) {
            ForEach(0..<totalCount, id: \.self) { index in
                if index < leadingCount {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    let day = section.days[index - leadingCount]
                    StreakDayCell(day: day) {
                        onDayTap(day)
                    }
                }
            }
        }
    }
}

// MARK: - Day cell

private struct StreakDayCell: View {
    let day: StreakDay
    let onTap: () -> Void

    private var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: StreakCalendarLayout.cellCornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: onTap) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay { cellContent }
                .clipShape(cellShape)
                .contentShape(cellShape)
                .overlay {
                    if day.hasPhoto {
                        cellShape.stroke(Color.orange.opacity(0.55), lineWidth: 1.5)
                    } else {
                        cellShape.stroke(SplickTheme.Colors.divider.opacity(0.3), lineWidth: 1)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(dayNumber)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(day.hasPhoto ? Color.orange : Color.gray.opacity(0.55))
                        )
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .disabled(!day.hasPhoto)
    }

    @ViewBuilder
    private var cellContent: some View {
        if day.hasPhoto, let url = day.firstThumbnailURL ?? day.firstPhotoURL {
            GridThumbnailImage(url: url) {
                cellShape.fill(SplickTheme.Colors.secondaryBackground)
            }
        } else {
            cellShape
                .fill(SplickTheme.Colors.secondaryBackground)
                .overlay {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textTertiary.opacity(0.45))
                }
        }
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: day.date))"
    }
}
