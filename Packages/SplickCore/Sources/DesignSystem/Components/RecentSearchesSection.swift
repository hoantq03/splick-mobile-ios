import SwiftUI
import Foundation
import Common
import Localization

public struct RecentSearchesSection: View {
    private let items: [SearchHistoryItem]
    private let languageService: LanguageService
    private let onSelect: (SearchHistoryItem) -> Void
    private let onDelete: (SearchHistoryItem) -> Void
    private let onClearAll: () -> Void

    public init(
        items: [SearchHistoryItem],
        languageService: LanguageService,
        onSelect: @escaping (SearchHistoryItem) -> Void,
        onDelete: @escaping (SearchHistoryItem) -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self.items = items
        self.languageService = languageService
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onClearAll = onClearAll
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                HStack {
                    Text(languageService.text(.searchHistoryTitle))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Spacer()
                    Button(languageService.text(.searchHistoryClearAll), action: onClearAll)
                        .font(SplickTheme.Typography.captionBold)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }

                ForEach(items) { item in
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        Button {
                            onSelect(item)
                        } label: {
                            HStack(spacing: SplickTheme.Spacing.sm) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                                Text(item.query)
                                    .font(SplickTheme.Typography.body)
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)

                        Button {
                            onDelete(item)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(languageService.text(.commonClear))
                    }
                    .padding(.vertical, SplickTheme.Spacing.xs)
                }
            }
        }
    }
}
