import SwiftUI
import DesignSystem

struct SocialSignInIconButton: View {
    enum Provider {
        case google
        case facebook
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
                        SplickSpinner(size: .small)
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
        case .google:
            ZStack {
                providerBackground
                Image("google-logo", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.iconSize, height: Self.iconSize)
            }
        case .facebook:
            ZStack {
                providerBackground
                Text("f")
                    .font(.system(size: Self.facebookGlyphFontSize, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: Self.facebookGlyphFrameSize, height: Self.facebookGlyphFrameSize)
                    .offset(x: Self.facebookGlyphXOffset, y: Self.facebookGlyphYOffset)
            }
        }
    }

    @ViewBuilder
    private var providerBackground: some View {
        switch provider {
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
        case .facebook:
            Circle()
                .fill(Self.facebookBlue)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
    }
}

private extension SocialSignInIconButton {
    static let buttonSize: CGFloat = 45
    static let iconSize: CGFloat = 21
    static let facebookBlue = Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)
    static let facebookGlyphFrameSize: CGFloat = 22
    static let facebookGlyphFontSize: CGFloat = 23
    static let facebookGlyphXOffset: CGFloat = 0.6
    static let facebookGlyphYOffset: CGFloat = -0.2
}

#if DEBUG
#Preview("Social icons") {
    HStack(spacing: 20) {
        SocialSignInIconButton(provider: .google, accessibilityLabel: "Google") {}
        SocialSignInIconButton(provider: .facebook, accessibilityLabel: "Facebook") {}
    }
    .padding()
}
#endif
