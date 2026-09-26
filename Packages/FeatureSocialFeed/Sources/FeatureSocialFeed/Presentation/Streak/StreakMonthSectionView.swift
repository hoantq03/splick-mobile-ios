import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct StreakMonthSectionView: View {
    @Environment(\.locale) private var locale

    let section: StreakMonthSection
    let onDayTap: (StreakDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(section.title)
                .font(.system(size: 22, weight: .semibold))
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
            ForEach(Array(StreakCalendarLayout.weekdaySymbols(locale: locale).enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
        if day.hasPhoto {
            StreakDayCover(day: day)
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

/// Image cover when one exists; otherwise the video's first decoded frame.
private struct StreakDayCover: View {
    let day: StreakDay
    @State private var generatedFrame: UIImage?

    private var stillURL: URL? {
        if let thumb = day.firstThumbnailURL, let photo = day.firstPhotoURL,
           let usable = VideoPosterURL.usableImageURL(thumb, videoURL: photo) {
            return usable
        }
        guard let candidate = day.firstThumbnailURL ?? day.firstPhotoURL else { return nil }
        return VideoPosterURL.usableImageURL(candidate, videoURL: URL(string: "https://cdn.splick.local/video.mp4")!)
    }

    private var videoURL: URL? {
        stillURL == nil ? (day.firstPhotoURL ?? day.firstThumbnailURL) : nil
    }

    var body: some View {
        Group {
            if let stillURL {
                GridThumbnailImage(url: stillURL) {
                    frameOrFill
                }
            } else {
                frameOrFill
            }
        }
        .task(id: videoURL?.absoluteString) {
            guard let videoURL else { return }
            if let cached = await VideoFirstFrameCache.shared.image(for: videoURL) {
                generatedFrame = cached
                return
            }
            generatedFrame = await VideoFirstFrameCache.shared.generate(for: videoURL)
        }
    }

    @ViewBuilder
    private var frameOrFill: some View {
        if let generatedFrame {
            Image(uiImage: generatedFrame)
                .resizable()
                .scaledToFill()
        } else {
            SplickTheme.Colors.secondaryBackground
        }
    }
}
