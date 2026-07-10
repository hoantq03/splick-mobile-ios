import SwiftUI
import UIKit

struct CommentAttachmentImageViewer: View {
    let images: [UIImage]
    let initialIndex: Int
    let onDismiss: () -> Void

    var body: some View {
        LocalImageFullscreenPreview(
            images: images,
            initialIndex: initialIndex,
            onDismiss: onDismiss
        )
    }
}
