import SwiftUI
import UIKit
import DesignSystem
import Localization

struct CustomEmojiCropTransform: Equatable {
    var viewportSize: CGSize = .zero
    var imageScale: CGFloat = 1
    var offset: CGSize = .zero
    var rotationDegrees: CGFloat = 0
    var flipHorizontal: Bool = false
    var crop: CGRect = .zero
}

struct CustomEmojiCropEditor: View {
    @EnvironmentObject private var languageService: LanguageService

    let sourceImage: UIImage
    @Binding var transform: CustomEmojiCropTransform

    private let maxScale: CGFloat = 6
    private let minCrop: CGFloat = 72
    private let inset: CGFloat = 14
    private let handleSize: CGFloat = 18
    private let handleHit: CGFloat = 28

    @State private var gestureScale: CGFloat = 1
    @State private var gestureOffset: CGSize = .zero
    @State private var dragStartCrop: CGRect = .zero
    @State private var activeHandle: CropHandle?

    var body: some View {
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

                    CropOverlay(
                        crop: transform.crop,
                        handleSize: handleSize
                    )
                    .allowsHitTesting(false)
                }
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous))
                .gesture(magnifyGesture)
                .simultaneousGesture(dragGesture(in: size))
                .onAppear {
                    ensureViewport(size)
                }
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

    private func dragGesture(in viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStartCrop == .zero {
                    dragStartCrop = transform.crop
                    activeHandle = hitHandle(value.startLocation, crop: transform.crop)
                }
                if let handle = activeHandle {
                    transform.crop = resizeCrop(
                        start: dragStartCrop,
                        handle: handle,
                        pointer: value.location,
                        viewport: viewport
                    )
                } else if dragStartCrop.contains(value.startLocation) {
                    transform.crop = moveCrop(
                        start: dragStartCrop,
                        delta: value.translation,
                        viewport: viewport
                    )
                } else {
                    gestureOffset = value.translation
                }
            }
            .onEnded { value in
                if activeHandle == nil, !dragStartCrop.contains(value.startLocation) {
                    transform.offset = CGSize(
                        width: transform.offset.width + value.translation.width,
                        height: transform.offset.height + value.translation.height
                    )
                }
                gestureOffset = .zero
                dragStartCrop = .zero
                activeHandle = nil
            }
    }

    private func ensureViewport(_ size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        transform.viewportSize = size
        if transform.crop.width < 2 {
            transform.crop = defaultCrop(in: size)
        }
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

    private func hitHandle(_ point: CGPoint, crop: CGRect) -> CropHandle? {
        let half = handleHit / 2
        func near(_ target: CGPoint) -> Bool {
            abs(point.x - target.x) <= half && abs(point.y - target.y) <= half
        }
        if near(CGPoint(x: crop.minX, y: crop.minY)) { return .topLeft }
        if near(CGPoint(x: crop.maxX, y: crop.minY)) { return .topRight }
        if near(CGPoint(x: crop.minX, y: crop.maxY)) { return .bottomLeft }
        if near(CGPoint(x: crop.maxX, y: crop.maxY)) { return .bottomRight }
        return nil
    }

    private func moveCrop(start: CGRect, delta: CGSize, viewport: CGSize) -> CGRect {
        let size = start.width
        let x = min(max(start.minX + delta.width, 0), max(viewport.width - size, 0))
        let y = min(max(start.minY + delta.height, 0), max(viewport.height - size, 0))
        return CGRect(x: x, y: y, width: size, height: size)
    }

    private func resizeCrop(start: CGRect, handle: CropHandle, pointer: CGPoint, viewport: CGSize) -> CGRect {
        let maxSize = min(viewport.width, viewport.height)
        let fixed: CGPoint
        switch handle {
        case .topLeft: fixed = CGPoint(x: start.maxX, y: start.maxY)
        case .topRight: fixed = CGPoint(x: start.minX, y: start.maxY)
        case .bottomLeft: fixed = CGPoint(x: start.maxX, y: start.minY)
        case .bottomRight: fixed = CGPoint(x: start.minX, y: start.minY)
        }
        let size = min(max(max(abs(pointer.x - fixed.x), abs(pointer.y - fixed.y)), minCrop), maxSize)
        let x = pointer.x < fixed.x ? fixed.x - size : fixed.x
        let y = pointer.y < fixed.y ? fixed.y - size : fixed.y
        let clampedX = min(max(x, 0), max(viewport.width - size, 0))
        let clampedY = min(max(y, 0), max(viewport.height - size, 0))
        return CGRect(x: clampedX, y: clampedY, width: size, height: size)
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

private enum CropHandle {
    case topLeft, topRight, bottomLeft, bottomRight
}

private struct CropOverlay: View {
    let crop: CGRect
    let handleSize: CGFloat

    var body: some View {
        Canvas { context, size in
            guard crop.width > 1 else { return }
            var outside = Path(CGRect(origin: .zero, size: size))
            let rectHole = Path(roundedRect: crop, cornerRadius: SplickTheme.CornerRadius.inset)
            outside.addPath(rectHole)
            context.fill(outside, with: .color(.black.opacity(0.52)), style: FillStyle(eoFill: true))

            var inscribedCorners = Path(roundedRect: crop, cornerRadius: SplickTheme.CornerRadius.inset)
            let circle = Path(ellipseIn: crop)
            inscribedCorners.addPath(circle)
            context.fill(inscribedCorners, with: .color(.black.opacity(0.28)), style: FillStyle(eoFill: true))

            context.stroke(
                rectHole,
                with: .color(.white.opacity(0.88)),
                lineWidth: 1.5
            )

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

            context.stroke(
                circle,
                with: .color(.white.opacity(0.95)),
                lineWidth: 2
            )

            let corners = [
                CGPoint(x: crop.minX, y: crop.minY),
                CGPoint(x: crop.maxX, y: crop.minY),
                CGPoint(x: crop.minX, y: crop.maxY),
                CGPoint(x: crop.maxX, y: crop.maxY),
            ]
            for corner in corners {
                let rect = CGRect(
                    x: corner.x - handleSize / 2,
                    y: corner.y - handleSize / 2,
                    width: handleSize,
                    height: handleSize
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 5),
                    with: .color(.white)
                )
            }
        }
    }
}

enum CustomEmojiCropRenderer {
    static func render(source: UIImage, transform: CustomEmojiCropTransform, outputSize: CGFloat = 256) -> UIImage {
        let crop = transform.crop
        let viewport = transform.viewportSize
        let oriented = CustomEmojiImageProcessor.normalizeOrientation(source)
        guard crop.width > 1, viewport.width > 1, viewport.height > 1, oriented.cgImage != nil else {
            return oriented
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

            // `UIImage.size` is orientation-aware; using raw cgImage pixels squashes EXIF photos.
            let fitted = aspectFit(imageSize: oriented.size, in: viewport)
            let drawRect = CGRect(
                x: -fitted.width / 2,
                y: -fitted.height / 2,
                width: fitted.width,
                height: fitted.height
            )
            oriented.draw(in: drawRect)
        }
    }

    static func aspectFit(imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }
        let ratio = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }
}
