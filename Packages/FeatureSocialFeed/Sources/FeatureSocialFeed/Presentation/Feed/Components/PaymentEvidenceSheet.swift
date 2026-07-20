import SwiftUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct PaymentEvidenceSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    let postAuthorName: String
    let onSubmit: (String?, [CommentSubmissionAttachment]) async throws -> Void

    @State private var message = ""
    @State private var pendingAttachments: [CommentSubmissionAttachment] = []
    @State private var validationMessage: String?
    @State private var isSubmitting = false
    @State private var fullScreenPreviewRoute: AttachmentPreviewRoute?

    init(
        postAuthorName: String,
        initialAttachments: [CommentSubmissionAttachment],
        onSubmit: @escaping (String?, [CommentSubmissionAttachment]) async throws -> Void
    ) {
        self.postAuthorName = postAuthorName
        self.onSubmit = onSubmit
        _pendingAttachments = State(initialValue: initialAttachments)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                Text(languageService.format(.feedPaymentEvidenceHint, postAuthorName))
                    .font(.system(size: 13))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(SplickTheme.Colors.error)
                }

                if !pendingAttachments.isEmpty {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                        Text(languageService.text(.feedPaymentEvidencePhotosLabel))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)

                        PendingAttachmentStrip(
                            attachments: pendingAttachments,
                            thumbnailWidth: 120,
                            thumbnailHeight: 156,
                            onTapAttachment: { index in
                                fullScreenPreviewRoute = AttachmentPreviewRoute(index: index)
                            },
                            onRemoveAttachment: { index in
                                removeAttachment(at: index)
                            }
                        )
                    }
                }

                TextField(languageService.text(.feedPaymentEvidenceMessagePlaceholder), text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    )

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(languageService.text(.feedPaymentEvidenceTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.feedPaymentEvidenceSubmit)) {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || pendingAttachments.isEmpty)
                }
            }
            .fullScreenCover(item: $fullScreenPreviewRoute) { route in
                let previewImages = LocalImagePreviewSupport.decodeImages(from: pendingAttachments)
                if previewImages.indices.contains(route.index) {
                    LocalImageFullscreenPreview(
                        images: previewImages,
                        initialIndex: route.index,
                        onDismiss: { fullScreenPreviewRoute = nil }
                    )
                }
            }
        }
    }

    private func removeAttachment(at index: Int) {
        guard pendingAttachments.indices.contains(index) else { return }
        pendingAttachments.remove(at: index)
        if let route = fullScreenPreviewRoute, route.index >= pendingAttachments.count {
            fullScreenPreviewRoute = nil
        }
    }

    @MainActor
    private func submit() async {
        guard !pendingAttachments.isEmpty else {
            validationMessage = languageService.text(.feedPaymentEvidenceAttachmentRequired)
            return
        }
        isSubmitting = true
        validationMessage = nil
        defer { isSubmitting = false }
        do {
            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            try await onSubmit(trimmedMessage.isEmpty ? nil : trimmedMessage, pendingAttachments)
            dismiss()
        } catch {
            validationMessage = languageService.localizedMessage(for: error)
        }
    }
}
