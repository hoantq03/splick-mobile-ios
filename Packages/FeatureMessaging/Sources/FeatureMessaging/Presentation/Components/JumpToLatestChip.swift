import SwiftUI
import DesignSystem
import Localization

/// Floating jump control when the user has scrolled away from the newest messages.
/// Slides up from below on appear and slides back down on dismiss.
struct JumpToLatestChip: View {
    @EnvironmentObject private var languageService: LanguageService
    let visible: Bool
    let onTap: () -> Void

    private static let hiddenOffset: CGFloat = 56

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "arrow.down")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(SplickTheme.Colors.cardBackground)
                        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.messagingJumpToLatest))
        .accessibilityHidden(!visible)
        .offset(y: visible ? 0 : Self.hiddenOffset)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .animation(ChatScrollAnimation.jumpToLatestReveal, value: visible)
    }
}
