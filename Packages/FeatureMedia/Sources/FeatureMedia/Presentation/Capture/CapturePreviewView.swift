import DesignSystem
import Localization
import SwiftUI

enum CapturePreviewStyle {
    /// After camera capture: confirm, retake, or edit before adding media.
    case capture
    /// Review already-selected media: preview and edit only.
    case review
}

struct CapturePreviewView: View {
    @EnvironmentObject private var languageService: LanguageService
    let image: UIImage
    var style: CapturePreviewStyle = .capture
    let onRetake: () -> Void
    let onEdit: () -> Void
    let onUsePhoto: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, SplickTheme.Spacing.sm)

                actionButtons
            }
        }
        .editorStatusBarHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }

            Spacer()

            Text(languageService.text(.mediaPreviewTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
    }

    private var actionButtons: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            if style == .capture {
                Button(action: onUsePhoto) {
                    Text(languageService.text(.mediaUsePhoto))
                        .font(SplickTheme.Typography.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
                }

                HStack(spacing: SplickTheme.Spacing.sm) {
                    secondaryButton(title: languageService.text(.mediaRetake), icon: "arrow.counterclockwise", action: onRetake)
                    secondaryButton(title: languageService.text(.mediaEdit), icon: "slider.horizontal.3", action: onEdit)
                }
            } else {
                Button(action: onEdit) {
                    Label(languageService.text(.mediaEdit), systemImage: "slider.horizontal.3")
                        .font(SplickTheme.Typography.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.lg)
        .background {
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func secondaryButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )
        }
        .buttonStyle(.plain)
    }
}
