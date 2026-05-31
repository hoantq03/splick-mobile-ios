import SwiftUI
import DesignSystem
import SplickDomain

/// Shown above the composer while replying (Facebook-style "Replying to …").
struct CommentReplyBanner: View {
    let replyingTo: UserSummary
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                Text("Đang trả lời ")
                    .font(.system(size: 12))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                Text(replyingTo.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(" (@\(replyingTo.username))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SplickTheme.Colors.info)
            }

            Spacer(minLength: 0)

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hủy trả lời")
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(SplickTheme.Colors.tertiaryBackground)
        )
    }
}
