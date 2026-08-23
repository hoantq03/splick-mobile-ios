import DesignSystem
import Localization
import SwiftUI

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
                    if !editing { viewModel.commitAdjustments() }
                }
            )
            .tint(.white)
        }
    }
}

struct EditorMoreOptionsSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: PhotoEditorViewModel
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Button(languageService.text(.mediaToolCrop)) {
                    onDismiss()
                    viewModel.selectTool(.crop)
                }
                Button(languageService.text(.mediaToolRotate)) {
                    onDismiss()
                    viewModel.selectTool(.rotate)
                }
                Button(languageService.text(.mediaToolAdjust)) {
                    onDismiss()
                    viewModel.selectTool(.adjust)
                }
            }
            .navigationTitle(languageService.text(.mediaToolMore))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonClose), action: onDismiss)
                }
            }
        }
    }
}
