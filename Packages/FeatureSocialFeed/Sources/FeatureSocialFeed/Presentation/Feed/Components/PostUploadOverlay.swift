import SwiftUI
import DesignSystem
import Localization
import Common

struct PostUploadOverlay: View {
    @EnvironmentObject private var languageService: LanguageService
    let state: PostUploadState
    var onRetry: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil

    var body: some View {
        let failedMessage: String? = {
            guard case .failed(let message, _) = state else { return nil }
            let title = languageService.text(.feedUploadFailed)
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == title ? nil : trimmed
        }()

        ZStack {
            Color.black.opacity(0.28)

            VStack(spacing: SplickTheme.Spacing.sm) {
                switch state {
                case .uploading:
                    SplickSpinner(size: .large)
                    Text(languageService.text(.feedUploadUploading))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                case .failed(_, let recovery):
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
                    Button {
                        if recovery == .edit {
                            onEdit?()
                        } else {
                            onRetry?()
                        }
                    } label: {
                        Text(
                            recovery == .edit
                                ? languageService.text(.feedUploadEditPost)
                                : languageService.text(.messagingTapToRetry)
                        )
                        .font(SplickTheme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.vertical, SplickTheme.Spacing.xs)
                        .background(.white.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
        .contentShape(Rectangle())
        .onTapGesture {
            if case .failed(_, .retry) = state {
                onRetry?()
            }
        }
        .allowsHitTesting(true)
    }
}
