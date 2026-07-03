import SwiftUI
import Common
import Localization

public struct LegalDocumentView: View {
    @EnvironmentObject private var languageService: LanguageService

    private let documentType: LegalDocumentType

    public init(documentType: LegalDocumentType) {
        self.documentType = documentType
    }

    public var body: some View {
        Group {
            if let bundled = LegalDocumentLoader.loadBundled(
                documentType,
                languageCode: languageService.locale.rawValue
            ) {
                LegalWebView(html: bundled.html, baseURL: bundled.baseURL)
            } else {
                LegalWebView(
                    remoteURL: documentType.webURL(languageCode: languageService.locale.rawValue)
                )
            }
        }
        .background(Color(red: 250 / 255, green: 250 / 255, blue: 250 / 255))
    }
}

public struct LegalDocumentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageService: LanguageService

    private let documentType: LegalDocumentType

    public init(documentType: LegalDocumentType) {
        self.documentType = documentType
    }

    public var body: some View {
        NavigationStack {
            LegalDocumentView(documentType: documentType)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(languageService.text(.commonClose)) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: documentType.webURL(languageCode: languageService.locale.rawValue)) {
                            Image(systemName: "safari")
                        }
                        .accessibilityLabel(languageService.text(.legalOpenInBrowser))
                    }
                }
        }
    }

    private var title: String {
        switch documentType {
        case .terms: return languageService.text(.legalTermsTitle)
        case .privacy: return languageService.text(.legalPrivacyTitle)
        }
    }
}

#if DEBUG
import Storage

#Preview("Terms") {
    struct PreviewWrapper: View {
        @StateObject private var languageService = LanguageService(userDefaults: UserDefaultsService())

        var body: some View {
            LegalDocumentView(documentType: .terms)
                .environmentObject(languageService)
                .languageService(languageService)
        }
    }
    return PreviewWrapper()
}
#endif
