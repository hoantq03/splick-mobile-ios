import SwiftUI

enum MessageSendAnimation {
    static let riseSpring = Animation.interpolatingSpring(stiffness: 180, damping: 16)
    static let duration: TimeInterval = 0.65

    struct FloatModifier: ViewModifier {
        let isActive: Bool
        let lateralSway: CGFloat

        @State private var phase: FloatPhase = .idle
        @State private var didPlayAnimation = false

        private enum FloatPhase {
            case idle
            case rising
            case settled
        }

        func body(content: Content) -> some View {
            content
                .offset(
                    x: phase == .rising ? lateralSway : 0,
                    y: phase == .rising ? -72 : 0
                )
                .scaleEffect(phase == .rising ? 0.85 : 1, anchor: .bottom)
                .opacity(phase == .rising ? 0.72 : 1)
                .onAppear { playFloatIfNeeded() }
                .onChange(of: isActive) { _ in playFloatIfNeeded() }
        }

        private func playFloatIfNeeded() {
            guard isActive, !didPlayAnimation else { return }
            didPlayAnimation = true
            phase = .rising
            withAnimation(riseSpring) {
                phase = .settled
            }
        }
    }
}

extension View {
    func messageSendFloat(isActive: Bool, lateralSway: CGFloat = 0) -> some View {
        modifier(MessageSendAnimation.FloatModifier(isActive: isActive, lateralSway: lateralSway))
    }
}
