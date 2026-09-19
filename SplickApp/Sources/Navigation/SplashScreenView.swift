import SwiftUI
import DesignSystem
import Localization

struct SplashScreenView: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var appState: AppState

    @State private var showBrand = false
    @State private var shimmering = false
    @State private var exitLogo = false
    @State private var exitTitle = false
    @State private var exitSlogan = false

    var body: some View {
        GeometryReader { proxy in
            let travel = proxy.size.width + 80
            ZStack {
                SplickBrandAtmosphere()

                VStack(spacing: 15) {
                    VStack(spacing: -22) {
                        SplickLogoMark(size: 160, layout: .markOnly, style: .fullColor)
                            .modifier(SplashSlideOut(isExiting: exitLogo, travel: travel))

                        SplickShimmerWordmark(isShimmering: shimmering && !exitTitle)
                            .modifier(SplashSlideOut(isExiting: exitTitle, travel: travel))
                    }

                    Text(languageService.text(.onboardingTagline))
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.xl)
                        .modifier(SplashSlideOut(isExiting: exitSlogan, travel: travel))
                }
                .padding(.horizontal, SplickTheme.Spacing.lg)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .modifier(SplashSlideIn(visible: showBrand))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await playIntro()
        }
        .task(id: appState.isLaunchSplashExiting) {
            guard appState.isLaunchSplashExiting else { return }
            await playExit()
        }
    }

    private func playIntro() async {
        withAnimation(SplashIntro.slide) {
            showBrand = true
        }
        try? await Task.sleep(for: .milliseconds(720))
        shimmering = true
    }

    private func playExit() async {
        shimmering = false
        withAnimation(SplashIntro.exit) {
            exitLogo = true
        }
        try? await Task.sleep(for: .milliseconds(SplashIntro.staggerMilliseconds))
        withAnimation(SplashIntro.exit) {
            exitTitle = true
        }
        try? await Task.sleep(for: .milliseconds(SplashIntro.staggerMilliseconds))
        withAnimation(SplashIntro.exit) {
            exitSlogan = true
        }
        try? await Task.sleep(for: .milliseconds(SplashIntro.exitMilliseconds))
        appState.completeLaunchSplash()
    }
}

private enum SplashIntro {
    static let slide = Animation.spring(response: 0.92, dampingFraction: 0.88, blendDuration: 0.16)
    /// Permanent off-screen exit: accelerate (Material standard-accelerate).
    /// Milder than emphasized-accelerate so it starts promptly after the hold, without crawling at the edge.
    static let exitMilliseconds: Int64 = 512
    /// 3 large rows: 50–80ms stagger so they overlap as one cascade, not three waits.
    static let staggerMilliseconds: Int64 = 48
    static let exit = Animation.timingCurve(0.30, 0.00, 1.00, 1.00, duration: 0.51)
}

private struct SplashSlideIn: ViewModifier {
    var visible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 36)
    }
}

private struct SplashSlideOut: ViewModifier {
    var isExiting: Bool
    var travel: CGFloat

    func body(content: Content) -> some View {
        content.modifier(SplashSlideTranslation(x: isExiting ? travel : 0))
    }
}

/// GPU translation interpolated every frame — avoids layout-offset hitching on large brand views.
private struct SplashSlideTranslation: ViewModifier, Animatable {
    var x: CGFloat

    var animatableData: CGFloat {
        get { x }
        set { x = newValue }
    }

    func body(content: Content) -> some View {
        content.transformEffect(CGAffineTransform(translationX: x, y: 0))
    }
}

private struct SplickShimmerWordmark: View {
    var isShimmering: Bool

    private let titleFont = Font.system(size: 52.5, weight: .heavy, design: .rounded)

    var body: some View {
        Text("Splick")
            .font(titleFont)
            .foregroundStyle(SplickTheme.Colors.brandWordmarkGradient)
            .overlay {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isShimmering)) { context in
                    let cycle = 1.85
                    let phase = isShimmering
                        ? CGFloat(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle)
                        : CGFloat(-0.2)
                    GeometryReader { geo in
                        let width = geo.size.width
                        let band = width * 0.46
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.92),
                                Color.white.opacity(0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: band)
                        .offset(x: -band + (width + band) * phase)
                        .blendMode(.plusLighter)
                    }
                }
                .mask(
                    Text("Splick")
                        .font(titleFont)
                )
            }
            .accessibilityAddTraits(.updatesFrequently)
    }
}
