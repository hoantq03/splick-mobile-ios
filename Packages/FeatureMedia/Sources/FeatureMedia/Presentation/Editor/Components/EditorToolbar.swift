import DesignSystem
import SwiftUI

struct EditorToolbar: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            if viewModel.isChromeVisible, viewModel.activeTool == .draw {
                drawOptionsBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if viewModel.isChromeVisible, viewModel.activeTool == .sticker {
                EditorStickerPickerBar(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            EditorToolScrollBar(
                viewModel: viewModel,
                onUndo: viewModel.undo,
                onRedo: viewModel.redo
            )
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }

            Spacer()

            Text("Chỉnh sửa")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)

            Spacer()

            Button(action: onDone) {
                Text("Xong")
                    .font(SplickTheme.Typography.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                    .background(
                        Capsule().fill(SplickTheme.Colors.primaryGradient)
                    )
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.xs)
    }

    private var drawOptionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.md) {
                ForEach(Array(PhotoEditorViewModel.inkPalette.enumerated()), id: \.offset) { _, color in
                    Button {
                        viewModel.inkColor = color
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Circle()
                            .fill(Color(color))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if viewModel.inkColor.isEqual(color) {
                                    Circle().strokeBorder(Color.white, lineWidth: 2.5)
                                }
                            }
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    }
                }

                Divider().frame(height: 28).overlay(Color.white.opacity(0.25))

                ForEach([3, 5, 8, 12], id: \.self) { width in
                    Button {
                        viewModel.inkWidth = CGFloat(width)
                    } label: {
                        Circle()
                            .fill(viewModel.inkWidth == CGFloat(width) ? Color.white : Color.white.opacity(0.35))
                            .frame(width: CGFloat(width + 6), height: CGFloat(width + 6))
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
        }
        .background(.ultraThinMaterial.opacity(0.85))
    }
}
