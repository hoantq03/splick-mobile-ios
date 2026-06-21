import PhotosUI
import SwiftUI
import UIKit
import DesignSystem
import Localization

public struct PaymentProfileManageView: View {
    @StateObject private var viewModel: PaymentProfileManageViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?

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

                SplickButton(
                    languageService.text(.profilePaymentSave),
                    isLoading: viewModel.isSaving,
                    isDisabled: viewModel.isSaving || viewModel.isDeleting
                ) {
                    Task {
                        if await viewModel.save() {
                            dismiss()
                        }
                    }
                }

                if viewModel.hasSavedProfile {
                    SplickButton(
                        languageService.text(.profilePaymentDelete),
                        style: .destructive,
                        isLoading: viewModel.isDeleting,
                        isDisabled: viewModel.isSaving || viewModel.isDeleting
                    ) {
                        viewModel.showDeleteConfirm = true
                    }
                }
            }
            .padding(SplickTheme.Spacing.lg)
        }
        .background(SplickTheme.Colors.background)
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
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.uploadQrImage(image)
                }
                selectedPhotoItem = nil
            }
        }
        .confirmationDialog(
            languageService.text(.profilePaymentDeleteConfirm),
            isPresented: $viewModel.showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(languageService.text(.profilePaymentDelete), role: .destructive) {
                Task {
                    if await viewModel.deleteProfile() {
                        dismiss()
                    }
                }
            }
        }
    }

    private var qrSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            sectionTitle(languageService.text(.profilePaymentQrSection))

            VStack(spacing: SplickTheme.Spacing.md) {
                if let url = viewModel.qrImageURL {
                    AsyncImage(url: url) { phase in
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
                                .frame(maxWidth: .infinity)
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(languageService.text(.profilePaymentUploadQr))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                        .background(SplickTheme.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous)
                                .strokeBorder(SplickTheme.Colors.primaryGradientStart, lineWidth: 1.5)
                        }
                }
                .disabled(viewModel.isSaving)
            }
            .padding(SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SplickTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.control, style: .continuous))
        }
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
