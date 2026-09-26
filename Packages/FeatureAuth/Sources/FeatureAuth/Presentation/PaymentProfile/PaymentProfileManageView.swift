import PhotosUI
import SwiftUI
import UIKit
import Common
import DesignSystem
import Localization

public struct PaymentProfileManageView: View {
    private enum QrImageAction {
        case view
        case change
        case remove
    }

    @StateObject private var viewModel: PaymentProfileManageViewModel
    @EnvironmentObject private var languageService: LanguageService
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showQrActions = false
    @State private var showQrViewer = false
    @State private var pendingQrAction: QrImageAction?

    public init(viewModel: PaymentProfileManageViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                qrSection
                bankSection

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }

                if viewModel.hasSavedProfile {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        saveButton
                        SplickButton(
                            languageService.text(.profilePaymentDelete),
                            style: .destructive,
                            isLoading: viewModel.isDeleting,
                            isDisabled: viewModel.isSaving || viewModel.isDeleting || viewModel.isUploadingQr
                        ) {
                            hideKeyboard()
                            viewModel.showDeleteConfirm = true
                        }
                    }
                } else {
                    saveButton
                }
            }
            .padding(SplickTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SplickTheme.Colors.background)
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(languageService.text(.commonDone)) {
                    hideKeyboard()
                }
            }
        }
        .navigationTitle(languageService.text(.profilePaymentTitle))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading {
                LoadingView(message: languageService.text(.profileLoading))
            }
        }
        .task {
            await viewModel.load()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { newItem in
            hideKeyboard()
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.uploadQrImage(image)
                }
                selectedPhotoItem = nil
            }
        }
        .onChange(of: showQrActions) { isPresented in
            guard !isPresented, let pendingQrAction else { return }
            self.pendingQrAction = nil
            switch pendingQrAction {
            case .view:
                showQrViewer = true
            case .change:
                showPhotoPicker = true
            case .remove:
                viewModel.removeQrImage()
            }
        }
        .confirmationDialog(
            languageService.text(.profilePaymentQrSection),
            isPresented: $showQrActions,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.profilePaymentViewQr)) {
                pendingQrAction = .view
            }
            Button(languageService.text(.profilePaymentChangeQr)) {
                pendingQrAction = .change
            }
            Button(languageService.text(.profilePaymentRemoveQr), role: .destructive) {
                pendingQrAction = .remove
            }
            Button(languageService.text(.commonCancel), role: .cancel) {
                pendingQrAction = nil
            }
        }
        .splickWindowFullScreenCover(isPresented: $showQrViewer) {
            if let url = viewModel.qrImageURL {
                SplickFullscreenRemoteImageOverlay(
                    url: url,
                    closeLabel: languageService.text(.commonClose),
                    onDismiss: { showQrViewer = false }
                )
            }
        }
        .confirmationDialog(
            languageService.text(.profilePaymentDeleteConfirm),
            isPresented: $viewModel.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.profilePaymentDelete), role: .destructive) {
                Task { _ = await viewModel.deleteProfile() }
            }
        }
    }

    private var saveButton: some View {
        SplickButton(
            languageService.text(.profilePaymentSave),
            isLoading: viewModel.isSaving,
            isDisabled: !viewModel.hasUnsavedChanges
                || viewModel.isSaving
                || viewModel.isDeleting
                || viewModel.isUploadingQr
        ) {
            hideKeyboard()
            Task { _ = await viewModel.save() }
        }
    }

    private var qrSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            sectionTitle(languageService.text(.profilePaymentQrSection))

            Group {
                if let preview = viewModel.qrUploadPreview {
                    qrLocalPreview(preview)
                } else if let url = viewModel.qrImageURL {
                    qrImagePreview(url: url)
                } else {
                    qrUploadPlaceholder
                }
            }
            .padding(SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        }
    }

    private var qrUploadPlaceholder: some View {
        Button {
            hideKeyboard()
            showPhotoPicker = true
        } label: {
            VStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(SplickTheme.Colors.brandBlue)
                Text(languageService.text(.profilePaymentQrTapToUpload))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180)
            .padding(SplickTheme.Spacing.md)
            .background(SplickTheme.Colors.secondaryBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous)
                    .strokeBorder(
                        SplickTheme.Colors.brandBlue.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploadingQr)
        .accessibilityLabel(languageService.text(.profilePaymentQrTapToUpload))
    }

    private func qrLocalPreview(_ image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .frame(maxWidth: .infinity)
            if viewModel.isUploadingQr {
                Color.black.opacity(0.28)
                SplickSpinner(usesBrandColors: false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        .accessibilityLabel(languageService.text(.profilePaymentQrSection))
    }

    private func qrImagePreview(url: URL) -> some View {
        Button {
            hideKeyboard()
            showQrActions = true
        } label: {
            ZStack {
                RemoteImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    case .failure:
                        Image(systemName: "qrcode")
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    default:
                        SplickSpinner()
                            .frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                if viewModel.isUploadingQr {
                    Color.black.opacity(0.28)
                    SplickSpinner(usesBrandColors: false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isUploadingQr)
        .accessibilityLabel(languageService.text(.profilePaymentQrSection))
    }

    private var bankSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            sectionTitle(languageService.text(.profilePaymentBankSection))

            VStack(spacing: SplickTheme.Spacing.md) {
                SplickTextField(
                    languageService.text(.profilePaymentAccountName),
                    text: $viewModel.accountName,
                    icon: "person"
                )
                .textContentType(.name)

                SplickTextField(
                    languageService.text(.profilePaymentAccountNumber),
                    text: $viewModel.accountNumber,
                    icon: "number"
                )
                .keyboardType(.numberPad)

                SplickTextField(
                    languageService.text(.profilePaymentBankName),
                    text: $viewModel.bankName,
                    icon: "building.columns"
                )
            }
            .padding(SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SplickTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(SplickTheme.Typography.headline)
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.leading, SplickTheme.Spacing.sm)
    }
}
