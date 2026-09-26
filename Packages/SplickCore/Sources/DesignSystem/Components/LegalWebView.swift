import SwiftUI
import UIKit
import WebKit
import Common

/// Loads live legal pages from the web; falls back to bundled HTML when offline / load fails.
struct LegalWebView: UIViewRepresentable {
    let remoteURL: URL?
    let fallbackHTML: String?
    let fallbackBaseURL: URL?
    var onLoadingChange: ((Bool) -> Void)?

    init(
        remoteURL: URL?,
        fallbackHTML: String? = nil,
        fallbackBaseURL: URL? = nil,
        onLoadingChange: ((Bool) -> Void)? = nil
    ) {
        self.remoteURL = remoteURL
        self.fallbackHTML = fallbackHTML
        self.fallbackBaseURL = fallbackBaseURL
        self.onLoadingChange = onLoadingChange
    }

    init(html: String, baseURL: URL) {
        self.remoteURL = nil
        self.fallbackHTML = html
        self.fallbackBaseURL = baseURL
        self.onLoadingChange = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadingChange: onLoadingChange)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = UIColor(red: 250 / 255, green: 250 / 255, blue: 250 / 255, alpha: 1)
        webView.navigationDelegate = context.coordinator
        context.coordinator.fallbackHTML = fallbackHTML
        context.coordinator.fallbackBaseURL = fallbackBaseURL
        context.coordinator.onLoadingChange = onLoadingChange
        context.coordinator.load(remoteURL: remoteURL, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.fallbackHTML = fallbackHTML
        context.coordinator.fallbackBaseURL = fallbackBaseURL
        context.coordinator.onLoadingChange = onLoadingChange

        let remoteChanged = context.coordinator.loadedRemoteURL != remoteURL
        guard remoteChanged else { return }
        context.coordinator.load(remoteURL: remoteURL, into: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var fallbackHTML: String?
        var fallbackBaseURL: URL?
        var onLoadingChange: ((Bool) -> Void)?
        private(set) var loadedRemoteURL: URL?
        private var didFallback = false

        init(onLoadingChange: ((Bool) -> Void)?) {
            self.onLoadingChange = onLoadingChange
        }

        func load(remoteURL: URL?, into webView: WKWebView) {
            didFallback = false
            loadedRemoteURL = remoteURL
            onLoadingChange?(true)

            if let remoteURL {
                var request = URLRequest(
                    url: remoteURL,
                    cachePolicy: .reloadIgnoringLocalCacheData,
                    timeoutInterval: 20
                )
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                webView.load(request)
                return
            }

            loadFallback(into: webView)
        }

        private func loadFallback(into webView: WKWebView) {
            guard !didFallback else {
                onLoadingChange?(false)
                return
            }
            didFallback = true
            if let fallbackHTML, let fallbackBaseURL {
                webView.loadHTMLString(fallbackHTML, baseURL: fallbackBaseURL)
            } else {
                onLoadingChange?(false)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadingChange?(false)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let host = url.host?.lowercased() ?? ""
            let allowedHosts: Set<String> = [
                AppConstants.Links.contentWebHost.lowercased(),
                AppConstants.Links.webHost.lowercased(),
            ]
            if allowedHosts.contains(host) || host.hasSuffix(".pages.dev") {
                decisionHandler(.allow)
                return
            }

            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            loadFallback(into: webView)
            onLoadingChange?(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            loadFallback(into: webView)
            onLoadingChange?(false)
        }
    }
}
