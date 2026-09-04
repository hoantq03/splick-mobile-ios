import SwiftUI
import Common
import Localization

public struct LegalDocumentView: View {
    @EnvironmentObject private var languageService: LanguageService

    private let documentType: LegalDocumentType
    @State private var isLoading = true

    public init(documentType: LegalDocumentType) {
        self.documentType = documentType
    }

    public var body: some View {
        let languageCode = languageService.locale.rawValue
        let remoteURL = documentType.webURL(languageCode: languageCode)
        let bundled = LegalDocumentLoader.loadBundled(documentType, languageCode: languageCode)

        ZStack {
            LegalWebView(
                remoteURL: remoteURL,
                fallbackHTML: bundled?.html,
                fallbackBaseURL: bundled?.baseURL,
                onLoadingChange: { loading in
                    isLoading = loading
                }
            )

            if isLoading {
                ProgressView()
                    .controlSize(.regular)
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
