import SwiftUI
import PhotosUI
import DesignSystem
import Localization
import SplickDomain

struct PaymentEvidenceSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    let postAuthorName: String
    let onSubmit: (String, [CommentSubmissionAttachment]) async throws -> Void

    @State private var message = ""
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var pendingAttachments: [CommentSubmissionAttachment] = []
    @State private var validationMessage: String?
    @State private var isSubmitting = false

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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, item in
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 10))
                                    Text(item.fileName ?? "photo")
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                    Button {
                                        pendingAttachments.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(SplickTheme.Colors.tertiaryBackground))
                            }
                        }
                    }
                }

                TextField(languageService.text(.feedPaymentEvidenceMessagePlaceholder), text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(SplickTheme.Colors.tertiaryBackground)
                    )

                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    Label(languageService.text(.feedPaymentEvidencePickPhoto), systemImage: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .medium))
                }
                .onChange(of: photoPickerItems) { items in
                    Task { await importPhotoPickerItems(items) }
                }

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
            try await onSubmit(message, pendingAttachments)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importPhotoPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let submission = CommentSubmissionAttachment(
                kind: .image,
                data: data,
                mimeType: "image/jpeg",
                fileName: "payment-proof.jpg"
            )
            pendingAttachments.append(submission)
        }
        photoPickerItems = []
    }
}
