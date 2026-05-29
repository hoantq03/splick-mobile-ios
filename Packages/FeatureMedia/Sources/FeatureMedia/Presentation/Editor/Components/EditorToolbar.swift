import DesignSystem
import SwiftUI

struct EditorToolbar: View {
    @Bindable var viewModel: PhotoEditorViewModel
    let onDone: () -> Void
    let onCancel: () -> Void

    @Namespace private var glassNamespace

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            toolBar
            actionBar
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.bottom, SplickTheme.Spacing.sm)
    }

    private var toolBar: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(EditorTool.allCases) { tool in
                            toolButton(tool)
                                .glassEffectID(tool.id, in: glassNamespace)
                        }

                        Divider()
                            .frame(height: 28)
                            .padding(.horizontal, SplickTheme.Spacing.xs)

                        undoButton
                            .glassEffectID("undo", in: glassNamespace)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.xs)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                }
            } else {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(EditorTool.allCases) { tool in
                        toolButton(tool)
                    }
                    undoButton
                }
                .padding(.horizontal, SplickTheme.Spacing.sm)
                .padding(.vertical, SplickTheme.Spacing.xs)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: SplickTheme.Spacing.md) {
            Button("Huỷ", action: onCancel)
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.sm)
                .background(fallbackGlassBackground)

            Button(action: onDone) {
                Label("Xong", systemImage: "checkmark")
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, SplickTheme.Spacing.sm)
            .background(fallbackGlassBackground)
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: EditorTool) -> some View {
        let isActive = viewModel.activeTool == tool

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                viewModel.setActiveTool(tool)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(tool.label)
                    .font(SplickTheme.Typography.caption)
            }
            .foregroundStyle(isActive ? SplickTheme.Colors.primaryGradientStart : SplickTheme.Colors.textPrimary)
            .frame(minWidth: 64)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .background {
                if isActive {
                    fallbackGlassBackground
                }
            }
        }
        .buttonStyle(.plain)
        .modifier(LiquidGlassToolModifier(isActive: isActive))
    }

    private var undoButton: some View {
        Button {
            viewModel.undo()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18, weight: .semibold))
                Text("Undo")
                    .font(SplickTheme.Typography.caption)
            }
            .foregroundStyle(viewModel.canUndo ? SplickTheme.Colors.textPrimary : SplickTheme.Colors.textTertiary)
            .frame(minWidth: 64)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .padding(.horizontal, SplickTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canUndo)
    }

    @ViewBuilder
    private var fallbackGlassBackground: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(.clear)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}

private struct LiquidGlassToolModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                isActive ? .regular.interactive() : .regular,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        } else {
            content
        }
    }
}
