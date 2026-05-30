import SwiftUI
import UIKit
import SplickDomain

struct SharePostSheet: UIViewControllerRepresentable {
    let post: Post

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = post.caption ?? "Xem bài viết trên Splick"
        let items: [Any] = [text, post.shareURL]
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
