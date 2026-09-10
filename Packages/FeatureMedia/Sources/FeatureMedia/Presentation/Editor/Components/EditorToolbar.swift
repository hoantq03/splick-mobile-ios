import DesignSystem
import Localization
import SwiftUI
import UIKit

struct EditorToolbar: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: PhotoEditorViewModel
    let activeComposerTool: ComposerTool?
    let onComposerTool: (ComposerTool) -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomPanels
            }

            HStack {
                Spacer()
                if viewModel.isChromeVisible {
                    EditorVerticalToolBar(activeTool: activeComposerTool, onSelect: onComposerTool)
                        .transition(.opacity)
                }
            }
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

            Button {
                viewModel.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.canUndo ? .white : .white.opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .disabled(!viewModel.canUndo)
            .accessibilityLabel(languageService.text(.mediaUndoA11y))

            Button {
                viewModel.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(viewModel.canRedo ? .white : .white.opacity(0.35))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.14)))
            }
            .disabled(!viewModel.canRedo)
            .accessibilityLabel(languageService.text(.mediaRedoA11y))

            Spacer()

            Button(action: onDone) {
                Text(languageService.text(.commonDone))
                    .font(SplickTheme.Typography.callout.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                    .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
            }
            .disabled(viewModel.isExporting)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.top, SplickTheme.Spacing.sm)
        .padding(.bottom, SplickTheme.Spacing.xs)
        .opacity(viewModel.isChromeVisible ? 1 : 0)
    }

    @ViewBuilder
    private var bottomPanels: some View {
        if viewModel.isChromeVisible, viewModel.activeTool == .draw {
            drawOptionsBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if viewModel.isChromeVisible, activeComposerTool == .edit {
            editSubtoolsBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if viewModel.isChromeVisible, viewModel.activeTool == .crop {
            cropOptionsBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if viewModel.isChromeVisible, activeComposerTool == .effects || viewModel.activeTool == .filter {
            ColorFilterStripView(preset: filterBinding)
                .padding(.vertical, SplickTheme.Spacing.sm)
                .background(.ultraThinMaterial.opacity(0.85))
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if viewModel.isChromeVisible, viewModel.activeTool == .adjust {
            adjustOptionsBar
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var drawOptionsBar: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.md) {
                Circle()
                    .fill(Color(viewModel.inkColor))
                    .frame(width: max(viewModel.inkWidth, 6), height: max(viewModel.inkWidth, 6))
                Slider(
                    value: Binding(
                        get: { Double(viewModel.inkWidth) },
                        set: { viewModel.inkWidth = CGFloat($0) }
                    ),
                    in: 2...28
                )
                .tint(.white)
            }

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
                }
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private var editSubtoolsBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            editSubtool(title: languageService.text(.mediaToolCrop), icon: "crop") {
                viewModel.selectTool(.crop)
            }
            editSubtool(title: languageService.text(.mediaToolRotate), icon: "rotate.right") {
                viewModel.selectTool(.rotate)
            }
            editSubtool(title: languageService.text(.mediaToolFlip), icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                viewModel.selectTool(.flip)
            }
            editSubtool(title: languageService.text(.mediaToolAdjust), icon: "slider.horizontal.3") {
                viewModel.selectTool(.adjust)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private func editSubtool(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
    }

    private var cropOptionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                ForEach(CropAspectPreset.allCases) { preset in
                    let selected = viewModel.selectedCropAspect == preset
                    Button {
                        viewModel.applyCropAspect(preset)
                    } label: {
                        Text(preset.title(using: languageService))
                            .font(.system(size: 13, weight: selected ? .bold : .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selected ? Color.white.opacity(0.28) : Color.white.opacity(0.14))
                            )
                            .overlay {
                                Capsule().strokeBorder(Color.white.opacity(selected ? 0.9 : 0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, SplickTheme.Spacing.sm)
        }
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private var filterBinding: Binding<FilterPreset> {
        Binding(
            get: { viewModel.activeFilter },
            set: { viewModel.setFilter($0) }
        )
    }

    private var adjustOptionsBar: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            adjustRow(title: languageService.text(.mediaAdjustBrightness), range: -1...1, keyPath: \.brightness)
            adjustRow(title: languageService.text(.mediaAdjustContrast), range: 0.5...1.5, keyPath: \.contrast)
            adjustRow(title: languageService.text(.mediaAdjustSaturation), range: 0...2, keyPath: \.saturation)
            adjustRow(title: languageService.text(.mediaAdjustExposure), range: -2...2, keyPath: \.exposure)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.sm)
        .background(.ultraThinMaterial.opacity(0.85))
    }

    private func adjustRow(
        title: String,
        range: ClosedRange<Double>,
        keyPath: WritableKeyPath<ImageAdjustments, Float>
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 88, alignment: .leading)
    Slider(
                    value: Binding(
                        get: { Double(viewModel.adjustments[keyPath: keyPath]) },
                        set: { newValue in
                            var next = viewModel.adjustments
                            next[keyPath: keyPath] = Float(newValue)
                            viewModel.setAdjustments(next)
                        }
                    ),
                    in: range,
                    onEditingChanged: { editing in
                        viewModel.setAdjustingLive(editing)
                        if !editing { viewModel.commitAdjustments() }
                    }
                )
            .tint(.white)
        }
    }
}

