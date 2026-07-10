import SwiftUI

struct CommentAttachmentMoreImagesOverlay: View {
    let hiddenCount: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
            Text("+\(hiddenCount)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Thêm \(hiddenCount) ảnh")
    }
}
