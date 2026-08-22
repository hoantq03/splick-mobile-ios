import DesignSystem
import Localization
import SwiftUI

struct EditorVerticalToolBar: View {
    @EnvironmentObject private var languageService: LanguageService
    let activeTool: ComposerTool?
    let onSelect: (ComposerTool) -> Void

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ForEach(ComposerTool.allCases) { tool in
                toolButton(tool)
            }
        }
        .padding(.trailing, SplickTheme.Spacing.sm)
    }

    private func toolButton(_ tool: ComposerTool) -> some View {
        let isActive = activeTool == tool
        let isDisabled = tool.isDisabled

        return Button {
            onSelect(tool)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDisabled ? .white.opacity(0.35) : (isActive ? .white : .white.opacity(0.9)))
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(isActive ? AnyShapeStyle(SplickTheme.Colors.primaryGradient) : AnyShapeStyle(Color.white.opacity(0.14)))
                    }

                Text(tool.title(using: languageService))
                    .font(.system(size: 10, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isDisabled ? .white.opacity(0.35) : (isActive ? .white : .white.opacity(0.75)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
