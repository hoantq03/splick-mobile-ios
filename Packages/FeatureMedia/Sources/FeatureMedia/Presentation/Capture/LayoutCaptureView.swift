import DesignSystem
import Localization
import SwiftUI
import UIKit

enum CollageLayout: String, CaseIterable, Identifiable {
    case twoByOne
    case threeGrid
    case fourGrid

    var id: String { rawValue }

    var cellCount: Int {
        switch self {
        case .twoByOne: return 2
        case .threeGrid: return 3
        case .fourGrid: return 4
        }
    }
}

struct LayoutCaptureView: View {
    @EnvironmentObject private var languageService: LanguageService
    let onBack: () -> Void
    let onCreated: (UIImage) -> Void

    @State private var layout: CollageLayout = .twoByOne
    @State private var slotImages: [UIImage?] = []
    @State private var activeSlot = 0
    @State private var showPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: SplickTheme.Spacing.md) {
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

                HStack(spacing: SplickTheme.Spacing.sm) {
                    ForEach(CollageLayout.allCases) { option in
                        Button {
                            layout = option
                            slotImages = Array(repeating: nil, count: option.cellCount)
                            activeSlot = 0
                        } label: {
                            Text("\(option.cellCount)")
                                .font(SplickTheme.Typography.captionBold)
                                .foregroundStyle(layout == option ? .black : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(layout == option ? Color.white : Color.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Text(languageService.text(.mediaCameraToolLayout))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                HStack(spacing: SplickTheme.Spacing.sm) {
                    ForEach(0..<layout.cellCount, id: \.self) { index in
                        Button {
                            activeSlot = index
                            showPicker = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 72, height: 72)
                                if let image = slotImages[safe: index] ?? nil {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    Text("+")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: composeCollage) {
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
                .disabled(slotImages.compactMap { $0 }.isEmpty)
            }
        }
        .sheet(isPresented: $showPicker) {
            MultiPhotoLibraryPickerView(
                maxSelectionCount: 1,
                onConfirm: { images in
                    guard let image = images.first else { return }
                    ensureSlotCapacity()
                    slotImages[activeSlot] = image
                    showPicker = false
                    activeSlot = min(activeSlot + 1, layout.cellCount - 1)
                },
                onCancel: { showPicker = false }
            )
        }
        .onAppear {
            slotImages = Array(repeating: nil, count: layout.cellCount)
        }
        .editorStatusBarHidden(true)
    }

    private func ensureSlotCapacity() {
        if slotImages.count != layout.cellCount {
            slotImages = Array(repeating: nil, count: layout.cellCount)
        }
    }

    private func composeCollage() {
        let images = slotImages.compactMap { $0 }
        guard !images.isEmpty, let collage = CollageComposer.compose(images: images, layout: layout) else { return }
        onCreated(collage)
    }
}

private enum CollageComposer {
    static func compose(images: [UIImage], layout: CollageLayout) -> UIImage? {
        let canvasSize = CGSize(width: 1080, height: 1080)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvasSize)).fill()

            let rects = frames(for: layout, in: canvasSize)
            for (index, rect) in rects.enumerated() {
                guard index < images.count else { continue }
                images[index].draw(in: rect)
            }
        }
    }

    private static func frames(for layout: CollageLayout, in size: CGSize) -> [CGRect] {
        switch layout {
        case .twoByOne:
            let half = size.width / 2
            return [
                CGRect(x: 0, y: 0, width: half, height: size.height),
                CGRect(x: half, y: 0, width: half, height: size.height),
            ]
        case .threeGrid:
            let cell = size.width / 2
            return [
                CGRect(x: 0, y: 0, width: cell, height: cell),
                CGRect(x: cell, y: 0, width: cell, height: cell),
                CGRect(x: 0, y: cell, width: size.width, height: cell),
            ]
        case .fourGrid:
            let cell = size.width / 2
            return [
                CGRect(x: 0, y: 0, width: cell, height: cell),
                CGRect(x: cell, y: 0, width: cell, height: cell),
                CGRect(x: 0, y: cell, width: cell, height: cell),
                CGRect(x: cell, y: cell, width: cell, height: cell),
            ]
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
