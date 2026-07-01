import Foundation

public enum LegalDocumentType: String, Sendable, CaseIterable, Identifiable, Hashable {
    case terms
    case privacy

    public var id: String { rawValue }

    fileprivate func resourceBaseName(languageCode: String) -> String {
        let suffix = languageCode == "vi" ? "vi" : "en"
        switch self {
        case .terms: return "terms_\(suffix)"
        case .privacy: return "privacy_\(suffix)"
        }
    }
}

public enum LegalDocumentLoader {
    private static let subdirectory = "Legal"

    /// Loads bundled markdown for the given document. `languageCode` should be `vi` or `en`.
    public static func load(_ type: LegalDocumentType, languageCode: String) -> String? {
        let name = type.resourceBaseName(languageCode: languageCode)
        guard let url = Bundle.module.url(forResource: name, withExtension: "md", subdirectory: subdirectory),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }
}
