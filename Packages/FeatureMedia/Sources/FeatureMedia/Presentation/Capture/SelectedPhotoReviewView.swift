import SwiftUI
import UIKit

/// Full-screen editor for a photo already attached to a compose draft.
public struct SelectedPhotoReviewView: View {
    let image: UIImage
    let sessionId: UUID
    let stickerPickerBuilder: MediaStickerPickerBuilder?
    let onImageUpdated: (UIImage) -> Void
    let onDismiss: () -> Void

    public init(
        image: UIImage,
        sessionId: UUID,
        stickerPickerBuilder: MediaStickerPickerBuilder? = nil,
        onImageUpdated: @escaping (UIImage) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.image = image
        self.sessionId = sessionId
        self.stickerPickerBuilder = stickerPickerBuilder
        self.onImageUpdated = onImageUpdated
        self.onDismiss = onDismiss
    }

    public var body: some View {
        PhotoEditorView(
            sourceImage: image,
            sessionId: sessionId,
            stickerPickerBuilder: stickerPickerBuilder,
            onDone: { edited in
                onImageUpdated(edited)
                onDismiss()
            },
            onCancel: onDismiss
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
