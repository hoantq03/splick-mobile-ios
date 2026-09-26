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
    @State private var showDrawColorWheel = false

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
        // Sit clearly under the notch / Dynamic Island (status bar is hidden in editor).
        .padding(.top, EditorLayout.windowSafeAreaTop + EditorLayout.topBarBelowSafeArea)
        .padding(.bottom, SplickTheme.Spacing.xs)
        .opacity(viewModel.isChromeVisible ? 1 : 0)
    }

    @ViewBuilder
    private var bottomPanels: some View {
        if viewModel.isChromeVisible, viewModel.activeTool == .draw {
            drawOptionsBar
                .overlay(alignment: .bottom) {
                    if showDrawColorWheel {
                        DrawInkColorWheel(
                            color: Binding(
                                get: { Color(viewModel.inkColor) },
                                set: { next in
                                    viewModel.inkColor = UIColor(next)
                                    viewModel.isErasing = false
                                }
                            ),
                            onCommit: { showDrawColorWheel = false }
                        )
                        .fixedSize()
                        .padding(.bottom, 8)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        if viewModel.isChromeVisible, viewModel.activeTool == .adjust {
            adjustOptionsBar
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
    }

    private var drawOptionsBar: some View {
        let customSelected = !viewModel.isErasing && (
            showDrawColorWheel || PhotoEditorViewModel.inkPalette.allSatisfy { !viewModel.inkColor.isEqual($0) }
        )
        return VStack(spacing: SplickTheme.Spacing.sm) {
            TaperedBrushSlider(width: $viewModel.inkWidth)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.md) {
                    Button {
                        viewModel.isErasing = true
                        showDrawColorWheel = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "eraser")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        viewModel.isErasing ? SplickTheme.Colors.primary : Color.clear,
                                        lineWidth: 2.5
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(languageService.text(.mediaDrawEraser))

                    ForEach(Array(PhotoEditorViewModel.inkPalette.enumerated()), id: \.offset) { _, color in
                        let selected = !viewModel.isErasing && viewModel.inkColor.isEqual(color)
                        Button {
                            viewModel.inkColor = color
                            viewModel.isErasing = false
                            showDrawColorWheel = false
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Circle()
                                .fill(Color(color))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Circle().strokeBorder(
                                        selected ? SplickTheme.Colors.primary : Color.white.opacity(0.55),
                                        lineWidth: selected ? 2.5 : 1
                                    )
                                }
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        viewModel.isErasing = false
                        showDrawColorWheel.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Circle()
                            .fill(
                                AngularGradient(
                                    colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                                    center: .center
                                )
                            )
                            .overlay {
                                Circle()
                                    .fill(Color(viewModel.inkColor))
                                    .padding(3)
                            }
                            .frame(width: 30, height: 30)
                            .overlay {
                                Circle().strokeBorder(
                                    customSelected ? SplickTheme.Colors.primary : Color.white.opacity(0.55),
                                    lineWidth: customSelected ? 2.5 : 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(languageService.text(.mediaDrawCustomColor))
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
            adjustRow(
                title: languageService.text(.mediaAdjustBrightness),
                range: -1...1,
                keyPath: \.brightness
            )
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
        let current = Double(viewModel.adjustments[keyPath: keyPath])
        return HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 88, alignment: .leading)
            WhiteDotSlider(
                value: Binding(
                    get: { Double(viewModel.adjustments[keyPath: keyPath]) },
                    set: { newValue in
                        var next = viewModel.adjustments
                        next[keyPath: keyPath] = Float(newValue)
                        viewModel.setAdjustments(next)
                    }
                ),
                range: range,
                onEditingChanged: { editing in
                    viewModel.setAdjustingLive(editing)
                    if !editing { viewModel.commitAdjustments() }
                }
            )
            Text(Self.adjustmentLevel(current, in: range))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
        }
    }

    /// Signed percent (−100…100) relative to the slider midpoint.
    static func adjustmentLevel(_ value: Double, in range: ClosedRange<Double>) -> String {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        let midpoint = (range.lowerBound + range.upperBound) / 2
        let percent = Int((((value - midpoint) / (span / 2)) * 100).rounded())
        let clamped = min(100, max(-100, percent))
        return clamped > 0 ? "+\(clamped)" : "\(clamped)"
    }

    /// Signed percent (−100…100) so the brightness slider has a readable level.
    static func brightnessLevel(_ value: Double) -> String {
        adjustmentLevel(value, in: -1...1)
    }
}

/// Thin white track with a white dot at the current adjustment.
private struct WhiteDotSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var onEditingChanged: (Bool) -> Void

    var body: some View {
        let span = max(range.upperBound - range.lowerBound, 0.0001)
        let fraction = min(max((value - range.lowerBound) / span, 0), 1)
        GeometryReader { geo in
            Canvas { context, size in
                let midY = size.height / 2
                let x = fraction * size.width
                var track = Path()
                track.move(to: CGPoint(x: 0, y: midY))
                track.addLine(to: CGPoint(x: size.width, y: midY))
                context.stroke(
                    track,
                    with: .color(.white.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                let dot = CGRect(x: x - 6, y: midY - 6, width: 12, height: 12)
                context.fill(Path(ellipseIn: dot), with: .color(.white))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onEditingChanged(true)
                        let nextFraction = min(max(gesture.location.x / max(geo.size.width, 1), 0), 1)
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * nextFraction
                    }
                    .onEnded { _ in
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 22)
        .accessibilityValue("\(Int(value.rounded()))")
    }
}

private struct DrawInkColorWheel: View {
    @Binding var color: Color
    var onCommit: () -> Void
    @State private var isDragging = false
    @State private var finger = CGPoint.zero
    @State private var preview = Color.white

    private let wheelSize: CGFloat = 176
    private let loupeSize: CGFloat = 52

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                        center: .center
                    )
                )
                .overlay {
                    Circle().fill(
                        RadialGradient(
                            colors: [.white, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: wheelSize / 2
                        )
                    )
                }
                .frame(width: wheelSize, height: wheelSize)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            finger = value.location
                            let next = color(at: value.location)
                            preview = next
                            color = next
                        }
                        .onEnded { value in
                            let next = color(at: value.location)
                            preview = next
                            color = next
                            isDragging = false
                            onCommit()
                        }
                )

            if isDragging {
                Circle()
                    .fill(preview)
                    .frame(width: loupeSize, height: loupeSize)
                    .overlay {
                        Circle().strokeBorder(.white, lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
                    .offset(x: loupeX, y: loupeY)
            }
        }
        .frame(width: wheelSize, height: wheelSize)
        .padding(.top, 6)
    }

    private var loupeX: CGFloat {
        let preferRight = finger.x < wheelSize * 0.62
        return preferRight ? finger.x + 18 : finger.x - 18 - loupeSize
    }

    private var loupeY: CGFloat {
        min(max(finger.y - loupeSize / 2, -loupeSize * 0.3), wheelSize - loupeSize * 0.7)
    }

    private func color(at point: CGPoint) -> Color {
        let center = wheelSize / 2
        let dx = point.x - center
        let dy = point.y - center
        let saturation = min(1, hypot(dx, dy) / center)
        var hue = atan2(dy, dx) / (2 * .pi)
        if hue < 0 { hue += 1 }
        return Color(hue: hue, saturation: saturation, brightness: 1)
    }
}

/// White wedge whose height at each point equals the brush width in points.
private struct TaperedBrushSlider: View {
    @Binding var width: CGFloat
    var minThickness: CGFloat = 2
    var maxThickness: CGFloat = 28
    @State private var lastTick = -1

    var body: some View {
        let span = max(maxThickness - minThickness, 1)
        let fraction = min(max((width - minThickness) / span, 0), 1)
        GeometryReader { geo in
            Canvas { context, size in
                let midY = size.height / 2
                let thumbX = fraction * size.width
                context.fill(
                    taper(width: size.width, thickness: maxThickness, midY: midY),
                    with: .color(.white.opacity(0.35))
                )
                if thumbX > 0.5 {
                    context.fill(
                        taper(width: thumbX, thickness: width, midY: midY),
                        with: .color(.white)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let nextFraction = min(max(value.location.x / geo.size.width, 0), 1)
                        let next = minThickness + (maxThickness - minThickness) * nextFraction
                        let tick = Int(next.rounded())
                        if tick != lastTick {
                            lastTick = tick
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                        width = next
                    }
            )
        }
        .frame(height: maxThickness + 8)
        .accessibilityValue("\(Int(width.rounded()))")
    }

    /// Trapezoid from `minThickness` on the left to `thickness` at `width`. Height is the stroke size.
    private func taper(width: CGFloat, thickness: CGFloat, midY: CGFloat) -> Path {
        let startHalf = minThickness / 2
        let endHalf = thickness / 2
        var path = Path()
        path.move(to: CGPoint(x: 0, y: midY - startHalf))
        path.addLine(to: CGPoint(x: width, y: midY - endHalf))
        path.addLine(to: CGPoint(x: width, y: midY + endHalf))
        path.addLine(to: CGPoint(x: 0, y: midY + startHalf))
        path.closeSubpath()
        return path
    }
}

