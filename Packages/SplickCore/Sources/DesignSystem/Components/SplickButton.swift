import SwiftUI

public struct SplickButton: View {
    public enum Style {
        case primary
        case secondary
        case destructive
        case ghost
    }

    private enum Phase: Equatable {
        case idle
        case loading
        case success
        case failed
    }

    @Environment(\.usesBrandAuthChrome) private var usesBrandAuthChrome
    private let title: String
    private let style: Style
    private let isLoading: Bool
    private let isFailed: Bool
    private let isDisabled: Bool
    private let cornerRadius: CGFloat
    private let action: () -> Void

    @State private var phase: Phase
    @State private var loadingStartedAt: Date?

    private var outcomeFlags: OutcomeFlags {
        OutcomeFlags(isLoading: isLoading, isFailed: isFailed)
    }

    public init(
        _ title: String,
        style: Style = .primary,
        isLoading: Bool = false,
        isFailed: Bool = false,
        isDisabled: Bool = false,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.control,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isFailed = isFailed
        self.isDisabled = isDisabled
        self.cornerRadius = cornerRadius
        self.action = action
        _phase = State(initialValue: isLoading ? .loading : .idle)
    }

    public var body: some View {
        Button {
            if phase == .idle {
                loadingStartedAt = Date()
                withAnimation(Self.morph) { phase = .loading }
            }
            action()
        } label: {
            ZStack {
                if phase == .idle {
                    Text(title)
                        .font(SplickTheme.Typography.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .transition(slideTransition)
                } else if phase == .loading {
                    SplickSpinner(
                        size: .medium,
                        usesBrandColors: spinnerUsesBrandColors,
                        side: Self.spinnerSide
                    )
                    .transition(slideTransition)
                } else if phase == .success {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .transition(slideTransition)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .transition(slideTransition)
                }
            }
            .frame(maxWidth: isCompact ? Self.buttonHeight : .infinity, alignment: .center)
            .frame(width: isCompact ? Self.buttonHeight : nil)
            .frame(height: Self.buttonHeight)
            .padding(.horizontal, phase == .idle ? SplickTheme.Spacing.lg : 0)
            .background {
                RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                    .fill(resolvedFill)
            }
            .foregroundStyle(resolvedForeground)
            .clipShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: resolvedCornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .disabled(isDisabled || phase != .idle)
        .opacity(isDisabled && phase == .idle ? 0.5 : 1.0)
        .animation(Self.morph, value: phase)
        .task(id: outcomeFlags) {
            await runOutcome(outcomeFlags)
        }
        .onAppear {
            restoreIdleIfNeeded()
        }
        .onDisappear {
            loadingStartedAt = nil
            phase = .idle
        }
    }

    private var primaryFill: AnyShapeStyle {
        switch style {
        case .primary:
            return AnyShapeStyle(SplickTheme.Colors.brandBlue)
        case .secondary, .ghost:
            return AnyShapeStyle(Color.clear)
        case .destructive:
            return AnyShapeStyle(SplickTheme.Colors.error)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary:
            return usesBrandAuthChrome ? SplickTheme.Colors.brandBlue : SplickTheme.Colors.primaryGradientStart
        case .ghost: return SplickTheme.Colors.textPrimary
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary:
            return usesBrandAuthChrome ? SplickTheme.Colors.brandBlue : SplickTheme.Colors.primaryGradientStart
        default: return .clear
        }
    }

    private var isCompact: Bool {
        phase != .idle
    }

    private var resolvedCornerRadius: CGFloat {
        isCompact ? Self.buttonHeight / 2 : cornerRadius
    }

    private var resolvedFill: AnyShapeStyle {
        switch phase {
        case .failed:
            return AnyShapeStyle(SplickTheme.Colors.brandPink)
        case .success:
            return AnyShapeStyle(SplickTheme.Colors.success)
        default:
            return primaryFill
        }
    }

    private var resolvedForeground: Color {
        if phase == .failed || phase == .success { return .white }
        return foregroundColor
    }

    private var showsBorder: Bool {
        phase == .idle && (style == .secondary)
    }

    private var spinnerUsesBrandColors: Bool {
        style == .secondary || style == .ghost
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private func restoreIdleIfNeeded() {
        guard !isLoading, phase != .loading, phase != .idle else { return }
        withAnimation(Self.morph) { phase = .idle }
    }

    @MainActor
    private func runOutcome(_ flags: OutcomeFlags) async {
        if flags.isLoading {
            if loadingStartedAt == nil {
                loadingStartedAt = Date()
            }
            withAnimation(Self.morph) { phase = .loading }
            return
        }
        if phase == .loading || phase == .success || phase == .failed {
            await waitOutMinimumLoading()
            if Task.isCancelled || isLoading { return }
            withAnimation(Self.morph) {
                phase = flags.isFailed ? .failed : .success
            }
            try? await Task.sleep(nanoseconds: Self.morphDurationNanoseconds)
            if Task.isCancelled || isLoading { return }
        }
        loadingStartedAt = nil
        withAnimation(Self.morph) { phase = .idle }
    }

    @MainActor
    private func waitOutMinimumLoading() async {
        let elapsed = loadingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let remaining = Self.minimumLoadingDuration - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
    }

    /// Shrink-to-spinner plus a visible spin, even when the API returns immediately.
    public static let minimumLoadingNanoseconds: UInt64 = 1_000_000_000
    private static var minimumLoadingDuration: TimeInterval {
        TimeInterval(minimumLoadingNanoseconds) / 1_000_000_000
    }
    private static let morphDurationNanoseconds: UInt64 = 480_000_000

    /// Time from API completion until the original button is restored (fastest API).
    public static let successHoldNanoseconds: UInt64 =
        minimumLoadingNanoseconds + morphDurationNanoseconds * 2

    private static let buttonHeight: CGFloat = 52
    private static let spinnerSide: CGFloat = 32
    private static let morph = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.48)
}

private struct OutcomeFlags: Equatable {
    var isLoading: Bool
    var isFailed: Bool
}

/// Compact header chip that pairs with the 32pt circular close control.
public struct SplickHeaderActionChip: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(SplickTheme.Colors.secondaryBackground.opacity(0.85))
                )
        }
        .buttonStyle(.plain)
    }
}
