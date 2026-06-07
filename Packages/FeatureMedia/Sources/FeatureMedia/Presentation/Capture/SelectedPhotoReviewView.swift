import SwiftUI
import UIKit

/// Full-screen preview and editor for a photo already attached to a compose draft.
public struct SelectedPhotoReviewView: View {
    let onImageUpdated: (UIImage) -> Void
    let onDismiss: () -> Void

    @State private var workingImage: UIImage
    @State private var isEditing = false

    public init(
        image: UIImage,
        onImageUpdated: @escaping (UIImage) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _workingImage = State(initialValue: image)
        self.onImageUpdated = onImageUpdated
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Group {
            if isEditing {
                PhotoEditorView(
                    sourceImage: workingImage,
                    onDone: { edited in
                        workingImage = edited
                        onImageUpdated(edited)
                        isEditing = false
                    },
                    onCancel: { isEditing = false }
                )
                .transition(.opacity)
            } else {
                CapturePreviewView(
                    image: workingImage,
                    style: .review,
                    onRetake: {},
                    onEdit: { isEditing = true },
                    onUsePhoto: {},
                    onCancel: onDismiss
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}
