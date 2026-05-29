import DesignSystem
import SwiftUI

struct EditorToolScrollBar: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let onUndo: () -> Void
    let onRedo: () -> Void

    var body: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.md) {
                    ForEach(EditorTool.allCases) { tool in
                        toolButton(tool)
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.xs)
            }

            HStack(spacing: SplickTheme.Spacing.xs) {
                historyButton(
                    icon: "arrow.uturn.backward",
                    isEnabled: viewModel.canUndo,
                    action: onUndo
                )
                historyButton(
                    icon: "arrow.uturn.forward",
                    isEnabled: viewModel.canRedo,
                    action: onRedo
                )
            }
            .padding(.trailing, SplickTheme.Spacing.md)
        }
        .padding(.vertical, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.xs)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func historyButton(icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isEnabled ? .white : .white.opacity(0.35))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .disabled(!isEnabled)
    }

    private func toolButton(_ tool: EditorTool) -> some View {
        let isActive = viewModel.activeTool == tool

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                viewModel.selectTool(tool)
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(isActive ? .white : .white.opacity(0.85))
                    .background {
                        Circle().fill(isActive ? AnyShapeStyle(SplickTheme.Colors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.14)))
                    }
                    .overlay {
                        if isActive {
                            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                        }
                    }

                Text(tool.label)
                    .font(.system(size: 11, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.65))
                    .lineLimit(1)
            }
            .frame(width: 58)
        }
        .buttonStyle(.plain)
    }
}
