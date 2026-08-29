import SwiftUI
import UIKit
import Localization

public struct AvatarCropTransform: Equatable {
    public var viewportSize: CGSize = .zero
    public var imageScale: CGFloat = 1
    public var offset: CGSize = .zero
    public var rotationDegrees: CGFloat = 0
    public var flipHorizontal: Bool = false
    public var crop: CGRect = .zero

    public init() {}
}

public struct AvatarCropEditor: View {
    @EnvironmentObject private var languageService: LanguageService

    let sourceImage: UIImage
    @Binding var transform: AvatarCropTransform

    private let maxScale: CGFloat = 6

    @State private var gestureScale: CGFloat = 1
    @State private var gestureOffset: CGSize = .zero

    public init(sourceImage: UIImage, transform: Binding<AvatarCropTransform>) {
        self.sourceImage = sourceImage
        self._transform = transform
    }

    public var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)
                        .scaleEffect(
                            x: displayedScale * (transform.flipHorizontal ? -1 : 1),
                            y: displayedScale
                        )
                        .rotationEffect(.degrees(transform.rotationDegrees))
                        .offset(displayedOffset)
                        .frame(width: size.width, height: size.height)
                        .clipped()

                    CircleCropOverlay(crop: transform.crop)
                        .allowsHitTesting(false)
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
                .gesture(magnifyGesture)
                .simultaneousGesture(panGesture)
                .onAppear { ensureViewport(size) }
                .onChange(of: size) { newSize in
                    ensureViewport(newSize)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            HStack(spacing: SplickTheme.Spacing.sm) {
                toolButton(
                    systemName: "rotate.left",
                    label: languageService.text(.stickersEmojiRotateLeft)
                ) {
                    transform.rotationDegrees = (transform.rotationDegrees - 90).truncatingRemainder(dividingBy: 360)
                    if transform.rotationDegrees < 0 { transform.rotationDegrees += 360 }
                }
                toolButton(
                    systemName: "rotate.right",
                    label: languageService.text(.stickersEmojiRotateRight)
                ) {
                    transform.rotationDegrees = (transform.rotationDegrees + 90).truncatingRemainder(dividingBy: 360)
                }
                toolButton(
                    systemName: "flip.horizontal",
                    label: languageService.text(.stickersEmojiFlip)
                ) {
                    transform.flipHorizontal.toggle()
                    transform.offset.width *= -1
                }
            }
        }
    }

    private var displayedScale: CGFloat {
        min(max(transform.imageScale * gestureScale, 1), maxScale)
    }

    private var displayedOffset: CGSize {
        CGSize(
            width: transform.offset.width + gestureOffset.width,
            height: transform.offset.height + gestureOffset.height
        )
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                gestureScale = value
            }
            .onEnded { value in
                transform.imageScale = min(max(transform.imageScale * value, 1), maxScale)
                gestureScale = 1
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                gestureOffset = value.translation
            }
            .onEnded { value in
                transform.offset = CGSize(
                    width: transform.offset.width + value.translation.width,
                    height: transform.offset.height + value.translation.height
                )
                gestureOffset = .zero
            }
    }

    private func ensureViewport(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        transform.viewportSize = size
        transform.crop = defaultCrop(in: size)
    }

    private func defaultCrop(in size: CGSize) -> CGRect {
        let cropSize = min(size.width, size.height) * 0.82
        return CGRect(
            x: (size.width - cropSize) / 2,
            y: (size.height - cropSize) / 2,
            width: cropSize,
            height: cropSize
        )
    }

    private func toolButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(SplickTheme.Colors.secondaryBackground))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct CircleCropOverlay: View {
    let crop: CGRect

    var body: some View {
        Canvas { context, size in
            guard crop.width > 1 else { return }
            var outside = Path(CGRect(origin: .zero, size: size))
            let circle = Path(ellipseIn: crop)
            outside.addPath(circle)
            context.fill(outside, with: .color(.black.opacity(0.55)), style: FillStyle(eoFill: true))

            let thirdW = crop.width / 3
            let thirdH = crop.height / 3
            var grid = Path()
            for i in 1...2 {
                let x = crop.minX + thirdW * CGFloat(i)
                let y = crop.minY + thirdH * CGFloat(i)
                grid.move(to: CGPoint(x: x, y: crop.minY))
                grid.addLine(to: CGPoint(x: x, y: crop.maxY))
                grid.move(to: CGPoint(x: crop.minX, y: y))
                grid.addLine(to: CGPoint(x: crop.maxX, y: y))
            }
            context.stroke(grid, with: .color(.white.opacity(0.32)), lineWidth: 1)
            context.stroke(circle, with: .color(.white.opacity(0.95)), lineWidth: 2)
        }
    }
}

public enum AvatarCropRenderer {
    public static func render(source: UIImage, transform: AvatarCropTransform, outputSize: CGFloat = 512) -> UIImage {
        let crop = transform.crop
        let viewport = transform.viewportSize
        guard crop.width > 1, viewport.width > 1, viewport.height > 1, let cgImage = source.cgImage else {
            return source
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderSize = CGSize(width: outputSize, height: outputSize)

        return UIGraphicsImageRenderer(size: renderSize, format: format).image { ctx in
            let cg = ctx.cgContext
            let scale = outputSize / crop.width
            cg.scaleBy(x: scale, y: scale)
            cg.translateBy(x: -crop.minX, y: -crop.minY)

            cg.translateBy(
                x: viewport.width / 2 + transform.offset.width,
                y: viewport.height / 2 + transform.offset.height
            )
            cg.rotate(by: transform.rotationDegrees * .pi / 180)
            let flip: CGFloat = transform.flipHorizontal ? -1 : 1
            cg.scaleBy(x: transform.imageScale * flip, y: transform.imageScale)

            let fitted = aspectFit(imageSize: CGSize(width: cgImage.width, height: cgImage.height), in: viewport)
            let drawRect = CGRect(
                x: -fitted.width / 2,
                y: -fitted.height / 2,
                width: fitted.width,
                height: fitted.height
            )
            source.draw(in: drawRect)
        }
    }

    private static func aspectFit(imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let ratio = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }
}
