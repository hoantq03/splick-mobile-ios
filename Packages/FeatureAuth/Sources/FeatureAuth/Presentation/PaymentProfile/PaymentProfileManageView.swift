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
        Form {
            Section(languageService.text(.profilePaymentQrSection)) {
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
                }
                .disabled(viewModel.isSaving)
            }

            Section(languageService.text(.profilePaymentBankSection)) {
                TextField(languageService.text(.profilePaymentAccountName), text: $viewModel.accountName)
                    .textContentType(.name)
                TextField(languageService.text(.profilePaymentAccountNumber), text: $viewModel.accountNumber)
                    .keyboardType(.numberPad)
                TextField(languageService.text(.profilePaymentBankName), text: $viewModel.bankName)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                }
            }

            Section {
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
}
