import SwiftUI
import PhotosUI
import UIKit
import DesignSystem
import FeatureMedia
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
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    header

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SplickTheme.Colors.error)
                            .padding(.horizontal, SplickTheme.Spacing.sm)
                            .padding(.vertical, SplickTheme.Spacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous)
                                    .fill(SplickTheme.Colors.error.opacity(0.10))
                            )
                    }

                    photoSection
                    messageField
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.top, SplickTheme.Spacing.sm)
                .padding(.bottom, SplickTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                        .disabled(isSubmitting)
                }
            }
            .safeAreaInset(edge: .bottom) {
                submitBar
            }
            .splickWindowFullScreenCover(item: $fullScreenPreviewRoute) { route in
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

    private var header: some View {
        HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.tile, style: .continuous)
                    .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                Image(systemName: "doc.text.image")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(languageService.text(.feedPaymentEvidenceTitle))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(languageService.format(.feedPaymentEvidenceHint, postAuthorName))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack {
                Text(languageService.text(.feedPaymentEvidencePhotosLabel))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Spacer()
                Text("\(pendingAttachments.count)/\(maxPhotos)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(SplickTheme.Colors.primaryGradientStart.opacity(0.10)))
            }

            if pendingAttachments.isEmpty {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: maxPhotos,
                    matching: .images
                ) {
                    emptyDropZone
                }
                .disabled(isSubmitting || isImportingPhotos)
                .buttonStyle(.plain)
            } else {
                photoGrid
            }
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            if isImportingPhotos {
                ProgressView()
            } else {
                ZStack {
                    Circle()
                        .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                }
            }
            Text(languageService.text(.feedPaymentEvidencePickPhoto))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text(languageService.text(.feedPaymentEvidenceAddPhoto))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.card, style: .continuous)
                .strokeBorder(
                    SplickTheme.Colors.primaryGradientStart.opacity(0.40),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
        }
    }

    private var photoGrid: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            ForEach(0..<maxPhotos, id: \.self) { index in
                Group {
                    if pendingAttachments.indices.contains(index) {
                        photoThumb(at: index)
                    } else if index == pendingAttachments.count {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: maxPhotos - pendingAttachments.count,
                            matching: .images
                        ) {
                            addPhotoTile
                        }
                        .disabled(isSubmitting || isImportingPhotos)
                        .buttonStyle(.plain)
                    } else {
                        placeholderSlot
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(0.72, contentMode: .fit)
            }
        }
        .animation(
            .spring(response: 0.32, dampingFraction: 0.78),
            value: pendingAttachments.count
        )
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous))
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
            .padding(7)
            .disabled(isSubmitting)
        }
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.82).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            )
        )
    }

    private var addPhotoTile: some View {
        VStack(spacing: 8) {
            if isImportingPhotos {
                ProgressView()
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
            }
            Text(languageService.text(.feedPaymentEvidenceAddPhoto))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .strokeBorder(
                    SplickTheme.Colors.primaryGradientStart.opacity(0.40),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
        }
    }

    private var placeholderSlot: some View {
        RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
            .fill(SplickTheme.Colors.tertiaryBackground.opacity(0.7))
            .overlay {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                    .strokeBorder(SplickTheme.Colors.divider.opacity(0.35), lineWidth: 1)
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
        .disabled(isSubmitting)
    }

    private var submitBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.35)
            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(languageService.text(.feedPaymentEvidenceSubmit))
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        pendingAttachments.isEmpty || isImportingPhotos || isSubmitting
                            ? SplickTheme.Colors.primaryGradientStart.opacity(0.38)
                            : SplickTheme.Colors.primaryGradientStart
                    )
            }
            .disabled(pendingAttachments.isEmpty || isImportingPhotos || isSubmitting)
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.top, SplickTheme.Spacing.sm)
            .padding(.bottom, SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.background)
        }
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
                  let jpegData = try? MediaImagePayload.jpegUploadData(from: image) else { continue }
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
