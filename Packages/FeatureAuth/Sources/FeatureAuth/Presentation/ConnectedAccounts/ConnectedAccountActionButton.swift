import SwiftUI
import DesignSystem

struct ConnectedAccountActionButton: View {
    enum Action {
        case link
        case unlink
    }

    let action: Action
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let accessibilityLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isLoading {
                    SplickSpinner(size: .small)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconName: String {
        switch action {
        case .link: return "plus.circle.fill"
        case .unlink: return "minus.circle.fill"
        }
    }

    private var iconColor: Color {
        switch action {
        case .link: return SplickTheme.Colors.primaryGradientStart
        case .unlink: return SplickTheme.Colors.error
        }
    }
}
