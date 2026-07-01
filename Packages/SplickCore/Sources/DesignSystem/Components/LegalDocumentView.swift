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
        ScrollView {
            Group {
                if let markdown = LegalDocumentLoader.load(documentType, languageCode: languageService.locale.rawValue) {
                    Text(attributedMarkdown(from: markdown))
                        .font(SplickTheme.Typography.body)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                } else {
                    Text(languageService.text(.legalDocumentLoadFailed))
                        .font(SplickTheme.Typography.body)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, SplickTheme.Spacing.xl)
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
    }

    private func attributedMarkdown(from markdown: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full)) {
            return attributed
        }
        return AttributedString(markdown)
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
                        if let url = externalURL {
                            Link(destination: url) {
                                Image(systemName: "safari")
                            }
                            .accessibilityLabel(languageService.text(.legalOpenInBrowser))
                        }
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

    private var externalURL: URL? {
        switch documentType {
        case .terms: return AppConstants.Links.termsOfServiceURL
        case .privacy: return AppConstants.Links.privacyPolicyURL
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
