import SwiftUI
import DesignSystem
import Localization

/// Inline peer typing row — incoming bubble with three dots cycling 1 → 2 → 3 (no bounce).
struct MessageTypingIndicatorBubble: View {
    @EnvironmentObject private var languageService: LanguageService

    private static let bubbleCornerRadius: CGFloat = 24
    private static let rowSideSpacer: CGFloat = 48
    private static let timestampSlotWidth: CGFloat = 46

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.xxs) {
            Color.clear
                .frame(width: Self.timestampSlotWidth)

            CyclingTypingDotsView()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Self.bubbleCornerRadius, style: .continuous)
                        .fill(SplickTheme.Colors.secondaryBackground)
                )

            Spacer(minLength: Self.rowSideSpacer)
        }
        .padding(.top, SplickTheme.Spacing.sm)
        .accessibilityLabel(languageService.text(.messagingChatTyping))
    }
}

/// Three dots; active count cycles 1 → 2 → 3 without vertical motion.
struct CyclingTypingDotsView: View {
    var dotSize: CGFloat = 8
    var dotSpacing: CGFloat = 4
    var activeColor: Color = SplickTheme.Colors.textSecondary.opacity(0.85)
    var inactiveColor: Color = SplickTheme.Colors.textSecondary.opacity(0.28)
    var stepDuration: TimeInterval = 0.45

    var body: some View {
        TimelineView(.periodic(from: .now, by: stepDuration)) { context in
            let activeCount = Int(context.date.timeIntervalSinceReferenceDate / stepDuration) % 3 + 1
            HStack(spacing: dotSpacing) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < activeCount ? activeColor : inactiveColor)
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
    }
}
