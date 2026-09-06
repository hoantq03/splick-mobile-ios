import SwiftUI
import DesignSystem
import Localization

struct PostUploadOverlay: View {
    @EnvironmentObject private var languageService: LanguageService
    let state: PostUploadState
    var onRetry: (() -> Void)? = nil

    var body: some View {
        let failedMessage: String? = {
            guard case .failed(let message) = state else { return nil }
            let title = languageService.text(.feedUploadFailed)
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == title ? nil : trimmed
        }()

        ZStack {
            Color.black.opacity(0.28)

            VStack(spacing: SplickTheme.Spacing.sm) {
                switch state {
                case .uploading:
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.large)
                        .tint(.white)
                    Text(languageService.text(.feedUploadUploading))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                    Text(languageService.text(.feedUploadFailed))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    if let failedMessage {
                        Text(failedMessage)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SplickTheme.Spacing.md)
                    }
                    Text(languageService.text(.messagingTapToRetry))
                        .font(SplickTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
        .contentShape(Rectangle())
        .onTapGesture {
            if case .failed = state {
                onRetry?()
            }
        }
        .allowsHitTesting(true)
    }
}
