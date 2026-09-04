import SwiftUI
import DesignSystem
import Localization

/// Floating chip above the composer when newer messages arrived while scrolled up.
struct JumpToLatestChip: View {
    @EnvironmentObject private var languageService: LanguageService
    let visible: Bool
    let onTap: () -> Void

    var body: some View {
        Group {
            if visible {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Text(languageService.text(.messagingJumpToLatest))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SplickTheme.Colors.primaryGradientStart)
                            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    )
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: visible)
    }
}
