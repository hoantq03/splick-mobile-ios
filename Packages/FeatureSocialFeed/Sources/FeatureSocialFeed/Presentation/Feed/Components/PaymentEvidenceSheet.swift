import SwiftUI
import PhotosUI
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
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var validationMessage: String?
    @State private var isSubmitting = false
    @State private var isImportingPhotos = false
    @State private var fullScreenPreviewRoute: AttachmentPreviewRoute?

    private let maxPhotos = 3
    private let thumbSize: CGFloat = 96

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
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                    Text(languageService.format(.feedPaymentEvidenceHint, postAuthorName))
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SplickTheme.Colors.error)
                    }

                    photoSection

                    messageField
                }
                .padding(SplickTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.feedPaymentEvidenceTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(languageService.text(.feedPaymentEvidenceSubmit)) {
                            Task { await submit() }
                        }
                        .fontWeight(.semibold)
                        .disabled(pendingAttachments.isEmpty || isImportingPhotos)
                    }
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: pickerItems) { items in
            Task { await importPickedPhotos(items) }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedPaymentEvidencePhotosLabel))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    ForEach(Array(pendingAttachments.enumerated()), id: \.offset) { index, _ in
                        photoThumb(at: index)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.82).combined(with: .opacity),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                )
                            )
                    }

                    if pendingAttachments.count < maxPhotos {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: maxPhotos - pendingAttachments.count,
                            matching: .images
                        ) {
                            addPhotoTile
                        }
                        .disabled(isSubmitting || isImportingPhotos)
                        .buttonStyle(.plain)
                    }
                }
                .animation(
                    .spring(response: 0.32, dampingFraction: 0.78),
                    value: pendingAttachments.count
                )
                .padding(.vertical, 4)
            }
        }
    }

    private func photoThumb(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                fullScreenPreviewRoute = AttachmentPreviewRoute(index: index)
            } label: {
                Group {
                    if let data = pendingAttachments[index].data, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        SplickTheme.Colors.tertiaryBackground
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                removeAttachment(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.black.opacity(0.55)))
            }
            .buttonStyle(.plain)
            .padding(6)
            .disabled(isSubmitting)
        }
    }

    private var addPhotoTile: some View {
        VStack(spacing: 8) {
            if isImportingPhotos {
                ProgressView()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            Text(languageService.text(.feedPaymentEvidencePickPhoto))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: thumbSize, height: thumbSize)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous)
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous)
                .strokeBorder(
                    SplickTheme.Colors.primaryGradientStart.opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
        }
    }

    private var messageField: some View {
        TextField(
            languageService.text(.feedPaymentEvidenceMessagePlaceholder),
            text: $message,
            axis: .vertical
        )
        .lineLimit(3...6)
        .padding(SplickTheme.Spacing.sm)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                .fill(SplickTheme.Colors.tertiaryBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .disabled(isSubmitting)
    }

    private func removeAttachment(at index: Int) {
        guard pendingAttachments.indices.contains(index) else { return }
        _ = withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            pendingAttachments.remove(at: index)
        }
        if let route = fullScreenPreviewRoute, route.index >= pendingAttachments.count {
            fullScreenPreviewRoute = nil
        }
    }

    @MainActor
    private func importPickedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isImportingPhotos = true
        defer {
            isImportingPhotos = false
            pickerItems = []
        }

        var imported: [CommentSubmissionAttachment] = []
        let startIndex = pendingAttachments.count
        for (offset, item) in items.enumerated() {
            guard pendingAttachments.count + imported.count < maxPhotos else { break }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.92) else { continue }
            imported.append(
                CommentSubmissionAttachment(
                    kind: .image,
                    data: jpegData,
                    mimeType: "image/jpeg",
                    fileName: "payment-proof-\(startIndex + offset + 1).jpg"
                )
            )
        }
        guard !imported.isEmpty else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            pendingAttachments.append(contentsOf: imported)
        }
        validationMessage = nil
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
