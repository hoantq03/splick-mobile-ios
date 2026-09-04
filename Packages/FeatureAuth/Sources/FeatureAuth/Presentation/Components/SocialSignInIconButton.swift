import SwiftUI
import DesignSystem

struct SocialSignInIconButton: View {
    enum Provider {
        case apple
        case google
    }

    let provider: Provider
    var accessibilityLabel: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ZStack {
                        providerBackground
                        ProgressView()
                            .tint(provider == .apple ? .white : nil)
                    }
                } else {
                    providerContent
                }
            }
            .frame(width: Self.buttonSize, height: Self.buttonSize)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.55 : 1)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var providerContent: some View {
        switch provider {
        case .apple:
            ZStack {
                providerBackground
                Image(systemName: "apple.logo")
                    .font(.system(size: Self.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
        case .google:
            ZStack {
                providerBackground
                Image("google-logo", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }
        }
    }

    @ViewBuilder
    private var providerBackground: some View {
        switch provider {
        case .apple:
            Circle()
                .fill(Color.black)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        case .google:
            Circle()
                .fill(Color.white)
                .overlay {
                    Circle()
                        .strokeBorder(
                            SplickTheme.Colors.textSecondary.opacity(0.2),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
    }
}

private extension SocialSignInIconButton {
    static let buttonSize: CGFloat = 45
    static let iconSize: CGFloat = 21
}

#if DEBUG
#Preview("Social icons") {
    HStack(spacing: 20) {
        SocialSignInIconButton(provider: .apple, accessibilityLabel: "Apple") {}
        SocialSignInIconButton(provider: .google, accessibilityLabel: "Google") {}
    }
    .padding()
}
#endif
