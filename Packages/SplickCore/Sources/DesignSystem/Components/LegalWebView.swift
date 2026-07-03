import SwiftUI
import WebKit

struct LegalWebView: UIViewRepresentable {
    let html: String?
    let baseURL: URL?
    let remoteURL: URL?

    init(html: String, baseURL: URL) {
        self.html = html
        self.baseURL = baseURL
        self.remoteURL = nil
    }

    init(remoteURL: URL) {
        self.html = nil
        self.baseURL = nil
        self.remoteURL = remoteURL
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = UIColor(red: 250 / 255, green: 250 / 255, blue: 250 / 255, alpha: 1)
        reload(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        reload(webView)
    }

    private func reload(_ webView: WKWebView) {
        if let html, let baseURL {
            webView.loadHTMLString(html, baseURL: baseURL)
        } else if let remoteURL {
            webView.load(URLRequest(url: remoteURL))
        }
    }
}
