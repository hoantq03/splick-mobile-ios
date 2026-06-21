import SwiftUI

enum SplashMotion {
    /// Splash curtain slides up; content underneath eases into place.
    static let reveal = Animation.spring(
        response: 0.74,
        dampingFraction: 0.86,
        blendDuration: 0.2
    )

    static let onboardingToLogin = Animation.spring(
        response: 0.58,
        dampingFraction: 0.9,
        blendDuration: 0.16
    )

    static var slideUpRemoval: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.2)),
            removal: .modifier(
                active: SplashSlideModifier(progress: 1),
                identity: SplashSlideModifier(progress: 0)
            )
            .combined(with: .opacity)
        )
    }

    static var loginInsertion: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .identity
        )
    }

    static var onboardingRemoval: AnyTransition {
        .asymmetric(
            insertion: .identity,
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

private struct SplashSlideModifier: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .frame(width: proxy.size.width, height: proxy.size.height)
                .offset(y: -progress * proxy.size.height)
        }
    }
}
