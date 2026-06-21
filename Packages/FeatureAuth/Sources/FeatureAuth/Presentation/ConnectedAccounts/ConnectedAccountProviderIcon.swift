import SwiftUI
import DesignSystem
import Localization

enum ConnectedAccountProviderKind {
    case google
    case email
    case phone
    case facebook

    @MainActor
    func titleKey(_ languageService: LanguageService) -> String {
        switch self {
        case .google:
            return languageService.text(.connectedAccountsProviderGoogle)
        case .email:
            return languageService.text(.connectedAccountsProviderEmail)
        case .phone:
            return languageService.text(.connectedAccountsProviderPhone)
        case .facebook:
            return languageService.text(.connectedAccountsProviderFacebook)
        }
    }
}

struct ConnectedAccountProviderIcon: View {
    let kind: ConnectedAccountProviderKind
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .overlay {
                    if kind == .google {
                        Circle()
                            .strokeBorder(
                                SplickTheme.Colors.textSecondary.opacity(0.18),
                                lineWidth: 1
                            )
                    }
                }

            content
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .google:
            Image("google-logo", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.52, height: size * 0.52)
        case .email:
            Image(systemName: "envelope.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.info)
                .symbolRenderingMode(.hierarchical)
        case .phone:
            Image(systemName: "phone.fill")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.success)
                .symbolRenderingMode(.hierarchical)
        case .facebook:
            Text("f")
                .font(.system(size: size * 0.5, weight: .black))
                .foregroundStyle(.white)
                .offset(x: 0.5, y: -0.5)
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .google:
            return .white
        case .email:
            return SplickTheme.Colors.info.opacity(0.12)
        case .phone:
            return SplickTheme.Colors.success.opacity(0.12)
        case .facebook:
            return Color(red: 24 / 255, green: 119 / 255, blue: 242 / 255)
        }
    }
}
