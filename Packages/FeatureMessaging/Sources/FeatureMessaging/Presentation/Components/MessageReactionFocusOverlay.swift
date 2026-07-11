import SwiftUI
import UIKit
import DesignSystem
import Localization

struct MessageReactionFocusOverlay: View {
    @EnvironmentObject private var languageService: LanguageService

    let context: MessageReactionFocusContext
    let onReact: (String) -> Void
    let onReply: () -> Void
    let onOpenFullPicker: () -> Void
    let onDismiss: () -> Void

    @State private var isRevealed = false
    @State private var actionStackSize: CGSize = CGSize(width: 280, height: 96)

    private let stackSpacing: CGFloat = 10
    private let traySpacing: CGFloat = 10
    private static let replyImpact = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .opacity(isRevealed ? 0.52 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissAnimated() }

            VStack(alignment: context.isOutgoing ? .trailing : .leading, spacing: stackSpacing) {
                replyButton
                MessageReactionTray(
                    onReact: onReact,
                    onOpenFullPicker: onOpenFullPicker,
                    onDismiss: dismissAnimated
                )
            }
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: ActionStackMeasuredSizeKey.self, value: geo.size)
                }
            }
            .onPreferenceChange(ActionStackMeasuredSizeKey.self) { actionStackSize = $0 }
            .scaleEffect(isRevealed ? 1 : 0.55, anchor: scaleAnchor)
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 14)
            .offset(x: stackOffsetX, y: stackOffsetY)
        }
        .animation(MessageReactionTrayMotion.present, value: isRevealed)
        .onAppear {
            isRevealed = false
            withAnimation(MessageReactionTrayMotion.present) {
                isRevealed = true
            }
        }
    }

    private var replyButton: some View {
        Button {
            Self.replyImpact.impactOccurred()
            onReply()
            dismissAnimated()
        } label: {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(languageService.text(.messagingReplyAction))
                    .font(SplickTheme.Typography.callout.weight(.semibold))
            }
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
            }
        }
        .buttonStyle(.plain)
    }

    private var scaleAnchor: UnitPoint {
        context.isOutgoing ? .bottomTrailing : .bottomLeading
    }

    private var stackOffsetX: CGFloat {
        context.isOutgoing
            ? context.frame.maxX - actionStackSize.width
            : context.frame.minX
    }

    private var stackOffsetY: CGFloat {
        context.frame.minY - traySpacing - actionStackSize.height
    }

    private func dismissAnimated() {
        onDismiss()
        withAnimation(MessageReactionTrayMotion.dismiss) {
            isRevealed = false
        }
    }
}

private struct ActionStackMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 280, height: 96)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1 {
            value = next
        }
    }
}
