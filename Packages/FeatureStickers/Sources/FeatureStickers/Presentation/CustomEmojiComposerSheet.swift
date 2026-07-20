import SwiftUI
import Common
import DesignSystem
import FeatureMedia
import Localization
import SplickDomain

public struct CustomEmojiComposerSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.dismiss) private var dismiss

    private let sourceImage: UIImage
    private let uploadMediaUseCase: UploadMediaUseCaseProtocol
    private let addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol
    private let onUploaded: ((CustomEmoji) -> Void)?

    @State private var alias = ""
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var committedScale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var committedRotation: Angle = .zero
    @State private var gestureRotation: Angle = .zero
    @State private var committedOffset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero

    private let cropCanvasSize: CGFloat = 192
    private let maxScale: CGFloat = 6

    public init(
        sourceImage: UIImage,
        uploadMediaUseCase: UploadMediaUseCaseProtocol,
        addEmojiUseCase: AddUserCustomEmojiUseCaseProtocol,
        onUploaded: ((CustomEmoji) -> Void)? = nil
    ) {
        self.sourceImage = sourceImage
        self.uploadMediaUseCase = uploadMediaUseCase
        self.addEmojiUseCase = addEmojiUseCase
        self.onUploaded = onUploaded
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    cropSection
                    aliasSection
                    uploadButton
                }
                .padding(SplickTheme.Spacing.md)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.stickersAddEmojiTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var cropSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.stickersEmojiCropTitle))
                .font(SplickTheme.Typography.headline)

            Text(languageService.text(.stickersEmojiCropHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(SplickTheme.Colors.secondaryBackground)
                        .frame(width: cropCanvasSize, height: cropCanvasSize)

                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: fittedImageSize.width, height: fittedImageSize.height)
                        .scaleEffect(renderedScale)
                        .rotationEffect(totalRotation)
                        .offset(totalOffset)
                        .frame(width: cropCanvasSize, height: cropCanvasSize)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .gesture(dragGesture)
                        .simultaneousGesture(magnificationGesture)
                        .simultaneousGesture(rotationGesture)

                    Circle()
                        .strokeBorder(SplickTheme.Colors.primaryGradientStart.opacity(0.7), lineWidth: 2)
                        .frame(width: cropCanvasSize, height: cropCanvasSize)
                        .allowsHitTesting(false)
                }
                Spacer()
            }
        }
    }

    private var aliasSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.stickersEmojiName))
                .font(SplickTheme.Typography.headline)

            TextField(languageService.text(.feedCustomEmojiShortcodePlaceholder), text: $alias)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            if !alias.isEmpty {
                Text(languageService.text(.stickersEmojiNameHint))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                Text(languageService.format(.stickersEmojiNamePreview, normalizedAlias))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private var uploadButton: some View {
        Button {
            Task { await upload() }
        } label: {
            if isUploading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text(languageService.text(.stickersUpload))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isUploading)
    }

    private var normalizedAlias: String {
        normalizeAlias(alias)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = clampedScale(value)
            }
            .onEnded { value in
                committedScale = clampedScale(committedScale * value)
                gestureScale = 1
                committedOffset = clampedOffset(
                    committedOffset,
                    scale: committedScale,
                    rotation: committedRotation
                )
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { value in
                gestureRotation = value
            }
            .onEnded { value in
                committedRotation += value
                gestureRotation = .zero
                committedOffset = clampedOffset(
                    committedOffset,
                    scale: committedScale,
                    rotation: committedRotation
                )
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                gestureOffset = CGSize(
                    width: clampedOffset(proposed, scale: currentScale, rotation: totalRotation).width - committedOffset.width,
                    height: clampedOffset(proposed, scale: currentScale, rotation: totalRotation).height - committedOffset.height
                )
            }
            .onEnded { value in
                let proposed = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                committedOffset = clampedOffset(proposed, scale: currentScale, rotation: totalRotation)
                gestureOffset = .zero
            }
    }

    private var totalRotation: Angle {
        committedRotation + gestureRotation
    }

    private var currentScale: CGFloat {
        clampedScale(committedScale * gestureScale)
    }

    private var renderedScale: CGFloat {
        minimumCoverScale * currentScale
    }

    private var totalOffset: CGSize {
        CGSize(
            width: committedOffset.width + gestureOffset.width,
            height: committedOffset.height + gestureOffset.height
        )
    }

    private var fittedImageSize: CGSize {
        aspectFitSize(for: sourceImage.size, inside: CGSize(width: cropCanvasSize, height: cropCanvasSize))
    }

    private var minimumCoverScale: CGFloat {
        let widthScale = cropCanvasSize / max(fittedImageSize.width, 1)
        let heightScale = cropCanvasSize / max(fittedImageSize.height, 1)
        return max(widthScale, heightScale)
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 1), maxScale)
    }

    private func clampedOffset(_ offset: CGSize, scale: CGFloat, rotation: Angle) -> CGSize {
        let baseWidth = fittedImageSize.width * minimumCoverScale * scale
        let baseHeight = fittedImageSize.height * minimumCoverScale * scale
        let radians = rotation.radians
        let halfWidth = abs(cos(radians)) * baseWidth / 2 + abs(sin(radians)) * baseHeight / 2
        let halfHeight = abs(sin(radians)) * baseWidth / 2 + abs(cos(radians)) * baseHeight / 2
        let cropRadius = cropCanvasSize / 2
        let maxOffsetX = max(halfWidth - cropRadius, 0)
        let maxOffsetY = max(halfHeight - cropRadius, 0)
        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }

    private func aspectFitSize(for imageSize: CGSize, inside boundingSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return boundingSize
        }
        let widthRatio = boundingSize.width / imageSize.width
        let heightRatio = boundingSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }

    private func normalizeAlias(_ rawValue: String) -> String {
        let folded = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: ":", with: "")

        var normalized = ""
        var previousWasSeparator = false

        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !normalized.isEmpty, !previousWasSeparator {
                normalized.append("_")
                previousWasSeparator = true
            }
        }

        return normalized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func croppedEmojiImage(outputSize: CGFloat = 256) -> UIImage {
        let renderSize = CGSize(width: outputSize, height: outputSize)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1

        return UIGraphicsImageRenderer(size: renderSize, format: format).image { context in
            let cgContext = context.cgContext
            let rect = CGRect(origin: .zero, size: renderSize)
            let canvasScale = outputSize / cropCanvasSize

            cgContext.clear(rect)
            cgContext.addEllipse(in: rect)
            cgContext.clip()
            cgContext.translateBy(
                x: rect.midX + totalOffset.width * canvasScale,
                y: rect.midY + totalOffset.height * canvasScale
            )
            cgContext.rotate(by: totalRotation.radians)
            cgContext.scaleBy(x: renderedScale * canvasScale, y: renderedScale * canvasScale)

            let drawRect = CGRect(
                x: -fittedImageSize.width / 2,
                y: -fittedImageSize.height / 2,
                width: fittedImageSize.width,
                height: fittedImageSize.height
            )
            sourceImage.draw(in: drawRect)
        }
    }

    @MainActor
    private func upload() async {
        isUploading = true
        defer { isUploading = false }

        do {
            let resolvedAlias = normalizedAlias
            if !resolvedAlias.isEmpty {
                guard CustomEmojiShortcodeValidator.isValid(resolvedAlias) else {
                    throw CustomEmojiError.invalidShortcode
                }
            }

            let image = croppedEmojiImage()
            let (data, mimeType) = try CustomEmojiImageProcessor.prepareUploadData(from: image)
            let upload = try await uploadMediaUseCase.execute(
                imageData: data,
                mimeType: mimeType,
                purpose: MediaUploadPurpose.userCustomEmoji,
                groupId: nil
            )
            let emoji = try await addEmojiUseCase.execute(
                alias: resolvedAlias.isEmpty ? nil : resolvedAlias,
                mediaId: upload.id
            )
            emojiStore.upsert(emoji)
            onUploaded?(emoji)
            dismiss()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}
