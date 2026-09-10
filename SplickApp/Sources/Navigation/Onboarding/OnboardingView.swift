import SwiftUI
import DesignSystem
import Common
import Localization

struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject private var languageService: LanguageService
    @State private var currentPage = 0
    @State private var hasCompleted = false

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(kind: .brand, background: .brand),
            OnboardingPage(
                kind: .feature,
                background: .capture,
                title: languageService.text(.onboardingSlide1Title),
                illustration: .cameraLens,
                accent: SplickTheme.Colors.primaryGradientStart
            ),
            OnboardingPage(
                kind: .feature,
                background: .bills,
                title: languageService.text(.onboardingSlide2Title),
                illustration: .splitBill,
                accent: SplickTheme.Colors.primaryGradientEnd
            ),
            OnboardingPage(
                kind: .feature,
                background: .friends,
                title: languageService.text(.onboardingSlide3Title),
                illustration: .overlappingHearts,
                accent: SplickTheme.Colors.primaryGradientMid
            ),
        ]
    }

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    ZStack {
                        OnboardingPageBackground(style: page.background)
                        pageView(page)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.38), value: currentPage)

            VStack {
                Spacer()
                pageIndicator
                if isLastPage {
                    Text(languageService.text(.onboardingCtaHint))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .padding(.top, SplickTheme.Spacing.xs)
                }
            }
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .background(SplickTheme.Colors.background)
        .contentShape(Rectangle())
        .simultaneousGesture(tapAdvanceGesture)
        .if(isLastPage) { view in
            view.highPriorityGesture(lastPageSwipeToLoginGesture)
        }
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            Spacer()

            switch page.kind {
            case .brand:
                brandPage
            case .feature:
                featurePage(page: page)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, SplickTheme.Spacing.xl)
    }

    private var brandPage: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            SplickLogoMark(size: 140, layout: .markOnly, style: .fullColor)

            Text("Splick")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(SplickTheme.Colors.primaryGradient)

            Text(languageService.text(.onboardingTagline))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, SplickTheme.Spacing.sm)
        }
    }

    private func featurePage(page: OnboardingPage) -> some View {
        VStack(spacing: SplickTheme.Spacing.xl) {
            ZStack {
                if page.background == .capture {
                    captureFeatureIcon
                } else {
                    defaultFeatureIcon(page: page)
                }
            }
            .shadow(color: page.accent.opacity(0.2), radius: 16, y: 8)

            Text(page.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(indicatorColor(for: index))
                    .frame(width: index == currentPage ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }

    private var captureFeatureIcon: some View {
        ZStack {
            OnboardingCameraCircleMotif(diameter: 140, style: .ring)
            OnboardingCameraCircleMotif(diameter: 108, style: .filled)
        }
    }

    private func defaultFeatureIcon(page: OnboardingPage) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            SplickTheme.Colors.primaryGradientStart.opacity(0.2),
                            SplickTheme.Colors.primaryGradientEnd.opacity(0.14),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 132, height: 132)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            SplickTheme.Colors.primaryGradientStart.opacity(0.35),
                            SplickTheme.Colors.primaryGradientEnd.opacity(0.25),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 132, height: 132)

            illustrationView(for: page.illustration, accent: page.accent)
        }
    }

    @ViewBuilder
    private func illustrationView(for illustration: OnboardingIllustration, accent: Color) -> some View {
        switch illustration {
        case .cameraLens:
            OnboardingCameraApertureView(size: 56)
        case .splitBill:
            OnboardingSplitBillView(size: 56)
        case .overlappingHearts:
            OnboardingOverlappingHeartsView(size: 56)
        case .systemImage(let name):
            Image(systemName: name)
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent, SplickTheme.Colors.primaryGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func indicatorColor(for index: Int) -> Color {
        if index == currentPage {
            switch pages[index].background {
            case .brand, .capture, .bills, .friends:
                return SplickTheme.Colors.primaryGradientStart
            }
        }
        return SplickTheme.Colors.textTertiary.opacity(0.35)
    }

    private var tapAdvanceGesture: some Gesture {
        TapGesture()
            .onEnded {
                advance()
            }
    }

    private var lastPageSwipeToLoginGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                guard isLastPage else { return }

                let horizontalTravel = value.translation.width
                let verticalTravel = value.translation.height
                guard abs(horizontalTravel) > abs(verticalTravel) else { return }
                guard horizontalTravel < -40 else { return }

                completeOnboarding()
            }
    }

    private func advance() {
        if isLastPage {
            completeOnboarding()
            return
        }

        withAnimation(.easeInOut(duration: 0.38)) {
            currentPage += 1
        }
    }

    private func completeOnboarding() {
        guard !hasCompleted else { return }
        hasCompleted = true
        // Let the current tap/drag gesture settle before swapping the whole root view.
        DispatchQueue.main.async {
            onComplete()
        }
    }
}

private struct OnboardingPage {
    enum Kind {
        case brand
        case feature
    }

    let kind: Kind
    let background: OnboardingBackgroundStyle
    var title: String = ""
    var illustration: OnboardingIllustration = .systemImage("star.fill")
    var accent: Color = SplickTheme.Colors.primaryGradientStart
}

private enum OnboardingIllustration {
    case cameraLens
    case splitBill
    case overlappingHearts
    case systemImage(String)
}
