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
    @State private var outcomeTask: Task<Void, Never>?

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
        Button(action: action) {
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
        .frame(maxWidth: phase == .idle ? .infinity : nil)
        .disabled(isDisabled || phase != .idle)
        .opacity(isDisabled && phase == .idle ? 0.5 : 1.0)
        .animation(Self.morph, value: phase)
        .onChange(of: isLoading) { loading in
            handleLoadingChange(loading)
        }
        .onChange(of: isFailed) { failed in
            guard !isLoading, failed, phase == .loading || phase == .success else { return }
            playOutcome(failed: true)
        }
        .onDisappear {
            outcomeTask?.cancel()
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

    private func handleLoadingChange(_ loading: Bool) {
        outcomeTask?.cancel()
        outcomeTask = nil
        if loading {
            withAnimation(Self.morph) { phase = .loading }
            return
        }
        playOutcome(failed: isFailed)
    }

    private func playOutcome(failed: Bool) {
        outcomeTask?.cancel()
        withAnimation(Self.morph) {
            phase = failed ? .failed : .success
        }
        outcomeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled, !isLoading else { return }
            withAnimation(Self.morph) { phase = .idle }
        }
    }

    private static let buttonHeight: CGFloat = 52
    private static let spinnerSide: CGFloat = 32
    private static let morph = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.48)
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
