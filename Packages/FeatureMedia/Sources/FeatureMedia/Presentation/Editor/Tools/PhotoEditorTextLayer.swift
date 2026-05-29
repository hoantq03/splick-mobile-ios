import DesignSystem
import SwiftUI

struct PhotoEditorTextLayer: View {
    @Bindable var viewModel: PhotoEditorViewModel
    let displayMetrics: ImageDisplayMetrics

    @State private var editingText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            ForEach(viewModel.textItems) { item in
                textOverlay(for: item)
            }
        }
        .onChange(of: viewModel.selectedTextID) { _, newValue in
            guard let id = newValue,
                  let item = viewModel.textItems.first(where: { $0.id == id }) else {
                isTextFieldFocused = false
                return
            }
            editingText = item.text
            isTextFieldFocused = true
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.activeTool == .text, viewModel.selectedTextID != nil {
                textEditorBar
            }
        }
    }

    @ViewBuilder
    private func textOverlay(for item: EditorTextItem) -> some View {
        let center = displayMetrics.imageNormalizedToView(item.normalizedPosition)
        let isSelected = viewModel.selectedTextID == item.id

        Text(item.text)
            .font(.system(size: 28 * item.scale, weight: .semibold, design: .rounded))
            .foregroundStyle(Color(item.color))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                }
            }
            .rotationEffect(item.rotation)
            .position(center)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard viewModel.activeTool == .text else { return }
                        updatePosition(id: item.id, to: value.location)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { scale in
                        guard viewModel.activeTool == .text,
                              let index = viewModel.textItems.firstIndex(where: { $0.id == item.id }) else { return }
                        viewModel.textItems[index].scale = max(0.5, min(scale, 3))
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .onChanged { angle in
                        guard viewModel.activeTool == .text,
                              let index = viewModel.textItems.firstIndex(where: { $0.id == item.id }) else { return }
                        viewModel.textItems[index].rotation = angle
                    }
            )
            .onTapGesture {
                guard viewModel.activeTool == .text else { return }
                viewModel.selectedTextID = item.id
            }
    }

    private var textEditorBar: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            TextField("Nhập chữ...", text: $editingText)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .submitLabel(.done)
                .onSubmit(commitEditing)

            Button("Xong", action: commitEditing)
                .font(SplickTheme.Typography.callout.weight(.semibold))
        }
        .padding(SplickTheme.Spacing.md)
        .background(.ultraThinMaterial)
    }

    private func updatePosition(id: UUID, to location: CGPoint) {
        guard let index = viewModel.textItems.firstIndex(where: { $0.id == id }) else { return }
        let frame = displayMetrics.displayFrame
        guard frame.width > 0, frame.height > 0 else { return }

        let normalized = CGPoint(
            x: min(max((location.x - frame.minX) / frame.width, 0), 1),
            y: min(max((location.y - frame.minY) / frame.height, 0), 1)
        )
        viewModel.textItems[index].normalizedPosition = normalized
    }

    private func commitEditing() {
        guard let id = viewModel.selectedTextID else { return }
        viewModel.updateText(id, text: editingText.isEmpty ? "Text" : editingText)
        viewModel.commitTextEdit()
        viewModel.selectedTextID = nil
        isTextFieldFocused = false
    }
}
