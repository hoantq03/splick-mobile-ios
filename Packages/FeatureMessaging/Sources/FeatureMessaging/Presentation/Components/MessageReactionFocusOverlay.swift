import SwiftUI
import DesignSystem

struct MessageReactionFocusOverlay: View {
    let context: MessageReactionFocusContext
    let onReact: (String) -> Void
    let onOpenFullPicker: () -> Void
    let onDismiss: () -> Void

    @State private var isRevealed = false
    @State private var traySize: CGSize = CGSize(width: 280, height: 52)

    private let traySpacing: CGFloat = 10

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .opacity(isRevealed ? 0.52 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissAnimated() }

            MessageReactionTray(
                onReact: onReact,
                onOpenFullPicker: onOpenFullPicker,
                onDismiss: dismissAnimated
            )
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: TrayMeasuredSizeKey.self, value: geo.size)
                }
            }
            .onPreferenceChange(TrayMeasuredSizeKey.self) { traySize = $0 }
            .scaleEffect(isRevealed ? 1 : 0.55, anchor: scaleAnchor)
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 14)
            .position(trayPosition)
        }
        .animation(MessageReactionTrayMotion.present, value: isRevealed)
        .onAppear {
            isRevealed = false
            withAnimation(MessageReactionTrayMotion.present) {
                isRevealed = true
            }
        }
    }

    private var scaleAnchor: UnitPoint {
        context.isOutgoing ? .bottomTrailing : .bottomLeading
    }

    private var trayPosition: CGPoint {
        let halfWidth = traySize.width / 2
        let halfHeight = traySize.height / 2
        let x = context.isOutgoing
            ? context.frame.maxX - halfWidth
            : context.frame.minX + halfWidth
        let y = context.frame.minY - traySpacing - halfHeight
        return CGPoint(x: x, y: y)
    }

    private func dismissAnimated() {
        onDismiss()
        withAnimation(MessageReactionTrayMotion.dismiss) {
            isRevealed = false
        }
    }
}

private struct TrayMeasuredSizeKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize(width: 280, height: 52)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 1, next.height > 1 {
            value = next
        }
    }
}
