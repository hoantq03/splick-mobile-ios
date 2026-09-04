import SwiftUI

public struct SplickButton: View {
    public enum Style {
        case primary
        case secondary
        case destructive
        case ghost
    }

    private let title: String
    private let style: Style
    private let isLoading: Bool
    private let isDisabled: Bool
    private let cornerRadius: CGFloat
    private let action: () -> Void

    public init(
        _ title: String,
        style: Style = .primary,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        cornerRadius: CGFloat = SplickTheme.CornerRadius.control,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.cornerRadius = cornerRadius
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                }
                Text(title)
                    .font(SplickTheme.Typography.headline)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if style == .secondary || style == .ghost {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: style == .ghost ? 0 : 1.5)
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return SplickTheme.Colors.primaryGradientStart
        case .secondary: return .clear
        case .destructive: return SplickTheme.Colors.error
        case .ghost: return .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return SplickTheme.Colors.primaryGradientStart
        case .ghost: return SplickTheme.Colors.textPrimary
        }
    }

    private var borderColor: Color {
        switch style {
        case .secondary: return SplickTheme.Colors.primaryGradientStart
        default: return .clear
        }
    }
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
