import SwiftUI
import DesignSystem
import Localization

struct PostUploadOverlay: View {
    @EnvironmentObject private var languageService: LanguageService
    let state: PostUploadState

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)

            VStack(spacing: SplickTheme.Spacing.sm) {
                switch state {
                case .uploading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                        .tint(.white)
                    Text(languageService.text(.feedCreatePosting))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                case .failed(let message):
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                    Text("Đăng thất bại")
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(message)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
    }
}
