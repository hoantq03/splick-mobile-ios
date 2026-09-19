import Foundation

public enum LegalDocumentType: String, Sendable, CaseIterable, Identifiable, Hashable {
    case terms
    case privacy

    public var id: String { rawValue }

    public var webURL: URL {
        webURL(languageCode: "en")
    }

    public func webURL(languageCode: String) -> URL {
        let isVietnamese = languageCode.lowercased().hasPrefix("vi")
        let host = AppConstants.Links.contentWebHost
        switch self {
        case .terms:
            let path = isVietnamese ? "/vi/terms/" : "/terms/"
            return URL(string: "https://\(host)\(path)")!
        case .privacy:
            let path = isVietnamese ? "/vi/privacy/" : "/privacy/"
            return URL(string: "https://\(host)\(path)")!
        }
    }

    fileprivate func resourceBaseName(languageCode: String) -> String {
        let suffix = languageCode == "vi" ? "vi" : "en"
        switch self {
        case .terms: return "terms_\(suffix)"
        case .privacy: return "privacy_\(suffix)"
        }
    }
}

public struct LegalBundledDocument: Sendable {
    public let html: String
    public let baseURL: URL
}

public enum LegalDocumentLoader {
    private static let subdirectory = "Legal"

    /// Loads bundled HTML fragment + stylesheet from the app package (offline fallback).
    /// Keep in sync with `splick-web/content/legal/html/*.html` when legal copy changes.
    public static func loadBundled(
        _ type: LegalDocumentType,
        languageCode: String
    ) -> LegalBundledDocument? {
        let normalized = normalizedLanguageCode(languageCode)
        let name = type.resourceBaseName(languageCode: normalized)

        if let document = readBundled(name: name) {
            return document
        }

        if normalized != "en" {
            let fallbackName = type.resourceBaseName(languageCode: "en")
            if let document = readBundled(name: fallbackName) {
                return document
            }
        }

        return nil
    }

    private static func normalizedLanguageCode(_ languageCode: String) -> String {
        languageCode.lowercased().hasPrefix("vi") ? "vi" : "en"
    }

    private static func readBundled(name: String) -> LegalBundledDocument? {
        guard let baseURL = Bundle.module.resourceURL?.appendingPathComponent(subdirectory, isDirectory: true),
              let fragmentURL = Bundle.module.url(
                forResource: name,
                withExtension: "html",
                subdirectory: subdirectory
              ),
              let fragment = try? String(contentsOf: fragmentURL, encoding: .utf8),
              !fragment.isEmpty else {
            return nil
        }

        let html = wrapFragment(fragment)
        return LegalBundledDocument(html: html, baseURL: baseURL)
    }

    private static func wrapFragment(_ fragment: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <link rel="stylesheet" href="legal.css">
          <style>
            body {
              margin: 0;
              padding: 16px 16px 32px;
              background: #fafafa;
              -webkit-text-size-adjust: 100%;
            }
          </style>
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }
}
