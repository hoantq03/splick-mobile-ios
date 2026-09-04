import SwiftUI
import UIKit
import Localization
import SplickDomain

struct SharePostSheet: UIViewControllerRepresentable {
    let post: Post
    let fallbackCaption: String

    init(post: Post, fallbackCaption: String) {
        self.post = post
        self.fallbackCaption = fallbackCaption
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let text = post.caption ?? fallbackCaption
        let items: [Any] = [text, post.shareURL]
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
