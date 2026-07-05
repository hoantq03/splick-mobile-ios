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
                Text("Gửi tối đa 3 ảnh chuyển khoản cho \(postAuthorName). Bạn có thể thêm lời nhắn nếu cần.")
                    .font(.system(size: 13))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(SplickTheme.Colors.error)
                }

                if !pendingAttachments.isEmpty {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                        Text("Ảnh chuyển khoản")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, item in
                                    ZStack(alignment: .topTrailing) {
                                        Group {
                                            if let image = previewImage(for: item) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                            } else {
                                                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium)
                                                    .fill(SplickTheme.Colors.tertiaryBackground)
                                                    .overlay {
                                                        Image(systemName: "photo")
                                                            .font(.system(size: 24))
                                                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                                                    }
                                            }
                                        }
                                        .frame(width: 120, height: 156)
                                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))

                                        Button {
                                            pendingAttachments.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundStyle(.white, .black.opacity(0.45))
                                        }
                                        .padding(6)
                                    }
                                }
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

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Upload ảnh chuyển khoản")
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
            validationMessage = "Vui lòng chọn ít nhất 1 ảnh chuyển khoản."
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
            validationMessage = error.localizedDescription
        }
    }

    private func previewImage(for attachment: CommentSubmissionAttachment) -> UIImage? {
        guard let data = attachment.data else { return nil }
        return UIImage(data: data)
    }
}
