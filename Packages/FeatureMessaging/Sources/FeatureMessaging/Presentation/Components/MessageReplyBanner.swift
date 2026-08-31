import SwiftUI
import DesignSystem
import Localization
import SplickDomain

enum MessageReplyIslandMotion {
    static let present = Animation.spring(response: 0.46, dampingFraction: 0.72, blendDuration: 0.05)
    static let dismiss = Animation.spring(response: 0.34, dampingFraction: 0.88, blendDuration: 0.04)
}

struct MessageReplyBanner: View {
    @EnvironmentObject private var languageService: LanguageService

    let draft: MessageReplyDraft
    let onCancel: () -> Void
    var onRevealOriginal: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(languageService.text(.messagingReplyingTo)) \(draft.senderDisplayName)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)

                    Text(previewText)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onRevealOriginal?()
            }

            Button {
                withAnimation(MessageReplyIslandMotion.dismiss) {
                    onCancel()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.text(.messagingReplyCancelAccessibility))
        }
        .padding(.leading, SplickTheme.Spacing.sm)
        .padding(.trailing, SplickTheme.Spacing.xs + 2)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, 2)
    }

    private var previewText: String {
        let trimmed = draft.bodySnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if draft.hasImageAttachment {
            return languageService.text(.messagingReplyPhoto)
        }
        return languageService.text(.messagingReplyEmpty)
    }
}

struct MessageEditBanner: View {
    @EnvironmentObject private var languageService: LanguageService

    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 28, height: 28)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                    }

                Text(languageService.text(.messagingEditingBanner))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                withAnimation(MessageReplyIslandMotion.dismiss) {
                    onCancel()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 26, height: 26)
                    .background {
                        Circle()
                            .fill(Color.white.opacity(0.16))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(languageService.text(.messagingEditCancelAccessibility))
        }
        .padding(.leading, SplickTheme.Spacing.sm)
        .padding(.trailing, SplickTheme.Spacing.xs + 2)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.88))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.xs)
        .padding(.bottom, 2)
    }
}

/// Dynamic Island–style morph: compact blob rises from below and expands into the pill.
struct ReplyIslandAppearModifier: ViewModifier {
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(
                x: 0.42 + 0.58 * progress,
                y: 0.28 + 0.72 * progress,
                anchor: .bottom
            )
            .offset(y: (1 - progress) * 36)
            .opacity(Double(progress))
    }
}

extension AnyTransition {
    static var replyIsland: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: ReplyIslandAppearModifier(progress: 0),
                identity: ReplyIslandAppearModifier(progress: 1)
            ),
            removal: .modifier(
                active: ReplyIslandAppearModifier(progress: 0),
                identity: ReplyIslandAppearModifier(progress: 1)
            )
        )
    }
}
