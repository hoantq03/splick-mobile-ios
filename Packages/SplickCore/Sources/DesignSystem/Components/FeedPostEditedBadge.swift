import SwiftUI
import Localization

/// Corner marker for edited feed posts — top/trailing curves match the post card radius.
public struct FeedPostEditedBadge: View {
    @EnvironmentObject private var languageService: LanguageService

    private let cornerRadius = SplickTheme.CornerRadius.card

    public init() {}

    public var body: some View {
        Text(languageService.text(.feedPostEdited))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(SplickTheme.Colors.warning)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                badgeShape
                    .fill(SplickTheme.Colors.warning.opacity(0.14))
            }
            .overlay {
                badgeShape
                    .strokeBorder(SplickTheme.Colors.warning.opacity(0.45), lineWidth: 0.75)
            }
            .accessibilityLabel(languageService.text(.feedPostEdited))
    }

    private var badgeShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: cornerRadius,
            bottomTrailingRadius: 0,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }
}

extension View {
    /// Sit this *outside* `matchedTransitionSource` — iOS 18 zoom clips overlays
    /// on the source view and the feed-list marker disappears after some pushes.
    public func feedPostEditedBadge(isEdited: Bool, action: @escaping () -> Void) -> some View {
        overlay(alignment: .topTrailing) {
            if isEdited {
                Button(action: action) {
                    FeedPostEditedBadge()
                }
                .buttonStyle(.plain)
            }
        }
    }
}
