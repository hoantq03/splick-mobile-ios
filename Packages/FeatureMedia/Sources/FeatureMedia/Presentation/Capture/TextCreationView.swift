import DesignSystem
import Localization
import SwiftUI
import UIKit

struct TextCreationView: View {
    @EnvironmentObject private var languageService: LanguageService
    let onBack: () -> Void
    let onCreated: (UIImage) -> Void

    @State private var text = ""
    @State private var gradientIndex = 0

    private let gradients: [[Color]] = [
        [Color(red: 0.51, green: 0.23, blue: 0.71), Color(red: 1, green: 0.11, blue: 0.11), Color(red: 0.99, green: 0.69, blue: 0.27)],
        [Color(red: 0, green: 0.36, blue: 0.59), Color(red: 0.21, green: 0.22, blue: 0.58)],
        [Color(red: 0.07, green: 0.6, blue: 0.56), Color(red: 0.22, green: 0.94, blue: 0.49)],
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradients[gradientIndex],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: SplickTheme.Spacing.lg) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    Spacer()
                }
                .padding(.horizontal, SplickTheme.Spacing.md)

                Spacer()

                Text(displayText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplickTheme.Spacing.lg)

                Spacer()

                TextField(languageService.text(.mediaTextPlaceholder), text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, SplickTheme.Spacing.lg)

                Button {
                    gradientIndex = (gradientIndex + 1) % gradients.count
                } label: {
                    Text(languageService.text(.mediaToolEffects))
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: renderAndFinish) {
                    Text(languageService.text(.commonDone))
                        .font(SplickTheme.Typography.callout.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                        .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, SplickTheme.Spacing.lg)
                .padding(.bottom, SplickTheme.Spacing.lg)
            }
        }
        .editorStatusBarHidden(true)
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? languageService.text(.mediaTextDefault) : trimmed
    }

    private func renderAndFinish() {
        let rendered = TextCreationRenderer.render(text: displayText, gradientIndex: gradientIndex, gradients: gradients)
        onCreated(rendered)
    }
}

private enum TextCreationRenderer {
    static func render(text: String, gradientIndex: Int, gradients: [[Color]]) -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgColors = gradients[gradientIndex].map { UIColor($0).cgColor } as CFArray
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors,
                locations: nil
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 56, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
            let rect = CGRect(x: 48, y: size.height * 0.35, width: size.width - 96, height: size.height * 0.3)
            (text as NSString).draw(in: rect, withAttributes: attributes)
        }
    }
}
