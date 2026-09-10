import DesignSystem
import Localization
import SwiftUI
import UIKit

private enum TextCreationTypeface: String, CaseIterable, Identifiable {
    case classic
    case rounded
    case serif
    case mono

    var id: String { rawValue }

    var titleKey: L10nKey {
        switch self {
        case .classic: return .mediaTextFontClassic
        case .rounded: return .mediaTextFontRounded
        case .serif: return .mediaTextFontSerif
        case .mono: return .mediaTextFontMono
        }
    }

    func font(size: CGFloat) -> Font {
        let design: Font.Design
        switch self {
        case .classic: design = .default
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .mono: design = .monospaced
        }
        return .system(size: size, weight: .bold, design: design)
    }

    func uiFont(size: CGFloat) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: .bold)
        let design: UIFontDescriptor.SystemDesign
        switch self {
        case .classic: design = .default
        case .rounded: design = .rounded
        case .serif: design = .serif
        case .mono: design = .monospaced
        }
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

private enum TextCreationLayout {
    static let horizontalPadding: CGFloat = 24
    static let topChrome: CGFloat = 56
    static let bottomChrome: CGFloat = 200
    static let fontSize: CGFloat = 32
}

struct TextCreationView: View {
    @EnvironmentObject private var languageService: LanguageService
    let onBack: () -> Void
    let onCreated: (UIImage) -> Void

    @State private var text = ""
    @State private var gradientIndex = 0
    @State private var alignment: TextAlignment = .center
    @State private var typeface: TextCreationTypeface = .classic
    @FocusState private var isTextFocused: Bool

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

            textEditor
                .padding(.horizontal, TextCreationLayout.horizontalPadding)
                .padding(.top, TextCreationLayout.topChrome)
                .padding(.bottom, TextCreationLayout.bottomChrome)

            VStack(spacing: SplickTheme.Spacing.sm) {
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

                HStack(spacing: 12) {
                    alignButton("text.alignleft", .leading, .mediaTextAlignLeft)
                    alignButton("text.aligncenter", .center, .mediaTextAlignCenter)
                    alignButton("text.alignright", .trailing, .mediaTextAlignRight)
                }

                HStack(spacing: 8) {
                    ForEach(TextCreationTypeface.allCases) { face in
                        Button {
                            typeface = face
                        } label: {
                            Text("Aa")
                                .font(face.font(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 36)
                                .background(
                                    Capsule().fill(Color.white.opacity(typeface == face ? 0.32 : 0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(languageService.text(face.titleKey))
                    }
                }

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
        .onAppear { isTextFocused = true }
    }

    private var textEditor: some View {
        ZStack {
            if text.isEmpty {
                Text(languageService.text(.mediaTextPlaceholder))
                    .font(typeface.font(size: TextCreationLayout.fontSize))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(alignment)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: canvasAlignment)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text, axis: .vertical)
                .font(typeface.font(size: TextCreationLayout.fontSize))
                .foregroundColor(.white)
                .multilineTextAlignment(alignment)
                .textFieldStyle(.plain)
                .tint(.white)
                .focused($isTextFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: canvasAlignment)
        }
    }

    private var canvasAlignment: Alignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }

    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? languageService.text(.mediaTextDefault) : text
    }

    private func alignButton(_ systemName: String, _ value: TextAlignment, _ key: L10nKey) -> some View {
        Button {
            alignment = value
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 36)
                .background(
                    Capsule().fill(Color.white.opacity(alignment == value ? 0.32 : 0.12))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(key))
    }

    private func renderAndFinish() {
        let rendered = TextCreationRenderer.render(
            text: displayText,
            colors: gradients[gradientIndex],
            typeface: typeface,
            alignment: alignment
        )
        onCreated(rendered)
    }
}

private enum TextCreationRenderer {
    static func render(
        text: String,
        colors: [Color],
        typeface: TextCreationTypeface,
        alignment: TextAlignment
    ) -> UIImage {
        let screen = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        let size = CGSize(width: screen.width * scale, height: screen.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgColors = colors.map { UIColor($0).cgColor } as CFArray
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
            paragraph.alignment = nsAlignment(alignment)
            paragraph.lineBreakMode = .byWordWrapping
            let font = typeface.uiFont(size: TextCreationLayout.fontSize * scale)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraph,
            ]
            let padX = TextCreationLayout.horizontalPadding * scale
            let padTop = TextCreationLayout.topChrome * scale
            let padBottom = TextCreationLayout.bottomChrome * scale
            let maxWidth = size.width - padX * 2
            let maxHeight = size.height - padTop - padBottom
            let bound = (text as NSString).boundingRect(
                with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            let drawHeight = min(ceil(bound.height), maxHeight)
            let originY = padTop + (maxHeight - drawHeight) / 2
            let drawRect = CGRect(x: padX, y: originY, width: maxWidth, height: drawHeight)
            (text as NSString).draw(
                with: drawRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
        }
    }

    private static func nsAlignment(_ alignment: TextAlignment) -> NSTextAlignment {
        switch alignment {
        case .leading: return .left
        case .trailing: return .right
        default: return .center
        }
    }
}
