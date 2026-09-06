import DesignSystem
import Localization
import SwiftUI

struct PhotoEditorTextLayer: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics

    var body: some View {
        ZStack {
            ForEach(viewModel.textItems) { item in
                TextOverlayItemView(
                    item: item,
                    center: viewModel.overlayDisplayPoint(item.normalizedPosition, metrics: displayMetrics),
                    isSelected: viewModel.selectedTextID == item.id,
                    isInteractive: viewModel.activeTool != .draw && viewModel.activeTool != .crop,
                    displayFrame: displayMetrics.displayFrame,
                    onSelect: { viewModel.selectedTextID = item.id },
                    onDeselect: { viewModel.deselectEditingText() },
                    onDelete: { viewModel.removeTextItem(item.id) },
                    onTextChange: { viewModel.updateText(item.id, text: $0) },
                    onEndEditing: {
                        if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || item.text == EditorTextItem.placeholderText {
                            viewModel.removeTextItem(item.id)
                        } else {
                            viewModel.commitTextEdit()
                        }
                    },
                    onMove: { viewModel.updateTextItemPosition(id: item.id, normalizedPosition: $0) },
                    onScale: { viewModel.updateTextItemScale(id: item.id, scale: $0) },
                    onRotate: { viewModel.updateTextItemRotation(id: item.id, rotation: $0) },
                    onTransformEnd: { viewModel.commitTextTransform() }
                )
            }
        }
    }
}

private struct TextOverlayItemView: View {
    @EnvironmentObject private var languageService: LanguageService
    let item: EditorTextItem
    let center: CGPoint
    let isSelected: Bool
    let isInteractive: Bool
    let displayFrame: CGRect
    let onSelect: () -> Void
    let onDeselect: () -> Void
    let onDelete: () -> Void
    let onTextChange: (String) -> Void
    let onEndEditing: () -> Void
    let onMove: (CGPoint) -> Void
    let onScale: (CGFloat) -> Void
    let onRotate: (Angle) -> Void
    let onTransformEnd: () -> Void

    @FocusState private var isFocused: Bool
    @State private var draft = ""
    @State private var dragOffset: CGSize = .zero
    @State private var liveScale: CGFloat = 1
    @State private var liveRotation: Angle = .zero

    private var isPlaceholder: Bool {
        item.text == EditorTextItem.placeholderText
    }

    private var displayText: String {
        if isPlaceholder {
            return EditorTextItem.defaultText(using: languageService)
        }
        return item.text
    }

    var body: some View {
        textContent
            .font(.system(size: 32 * item.scale * liveScale, weight: .bold, design: .rounded))
            .foregroundStyle(Color(item.color))
            .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected, isInteractive {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                }
            }
            .rotationEffect(item.rotation + liveRotation)
            .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
            .allowsHitTesting(isInteractive)
            .contentShape(Rectangle())
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnifyGesture)
            .simultaneousGesture(rotateGesture)
            .onTapGesture {
                guard isInteractive, !isSelected else { return }
                onSelect()
            }
            .onChange(of: isSelected) { selected in
                if selected {
                    draft = isPlaceholder ? "" : item.text
                }
                isFocused = selected
                if !selected {
                    DispatchQueue.main.async {
                        onEndEditing()
                    }
                }
            }
            .onChange(of: isFocused) { focused in
                if !focused, isSelected {
                    onDeselect()
                }
            }
            .onAppear {
                draft = isPlaceholder ? "" : item.text
                if isSelected {
                    isFocused = true
                }
            }
    }

    private var maxTextWidth: CGFloat {
        max(displayFrame.width - 32, 80)
    }

    @ViewBuilder
    private var textContent: some View {
        let ink = Color(item.color)
        let live: String = {
            if isSelected {
                return draft.isEmpty
                    ? EditorTextItem.defaultText(using: languageService)
                    : draft
            }
            return displayText
        }()
        ZStack {
            Text(live)
                .multilineTextAlignment(.center)
                .lineLimit(1...12)
                .frame(maxWidth: maxTextWidth)
                .fixedSize(horizontal: true, vertical: true)
                .hidden()

            if isSelected, isInteractive {
                Text(live)
                    .foregroundStyle(ink)
                    .opacity(draft.isEmpty ? 0.55 : 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(1...12)
                    .frame(maxWidth: maxTextWidth)
                    .fixedSize(horizontal: true, vertical: true)
                    .allowsHitTesting(false)

                TextField("", text: draftBinding, axis: .vertical)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.clear)
                    .tint(ink)
                    .lineLimit(1...12)
                    .frame(maxWidth: maxTextWidth)
                    .fixedSize(horizontal: true, vertical: true)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { isFocused = false }
            } else {
                Text(displayText)
                    .foregroundStyle(ink)
                    .opacity(isPlaceholder ? 0.7 : 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(1...12)
                    .frame(maxWidth: maxTextWidth)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { draft },
            set: { newValue in
                draft = newValue
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                onTextChange(trimmed.isEmpty ? EditorTextItem.placeholderText : newValue)
            }
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let location = CGPoint(
                    x: center.x + value.translation.width,
                    y: center.y + value.translation.height
                )
                onMove(normalizedPoint(for: location))
                dragOffset = .zero
                onTransformEnd()
            }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { liveScale = $0 }
            .onEnded { scale in
                onScale(max(0.35, min(item.scale * scale, 8)))
                liveScale = 1
                onTransformEnd()
            }
    }

    private var rotateGesture: some Gesture {
        RotationGesture()
            .onChanged { liveRotation = $0 }
            .onEnded { angle in
                onRotate(item.rotation + angle)
                liveRotation = .zero
                onTransformEnd()
            }
    }

    private func normalizedPoint(for location: CGPoint) -> CGPoint {
        guard displayFrame.width > 0, displayFrame.height > 0 else { return item.normalizedPosition }
        return CGPoint(
            x: min(max((location.x - displayFrame.minX) / displayFrame.width, 0), 1),
            y: min(max((location.y - displayFrame.minY) / displayFrame.height, 0), 1)
        )
    }
}
