import Foundation
import SplickDomain
import UIKit

@MainActor
public final class PaymentProfileManageViewModel: ObservableObject {
    @Published var qrImageURL: URL?
    @Published var accountName = ""
    @Published var accountNumber = ""
    @Published var bankName = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var errorMessage: String?
    @Published var showDeleteConfirm = false

    private let fetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCaseProtocol
    private let upsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCaseProtocol
    private let deleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCaseProtocol
    private let uploadPaymentQr: (UIImage) async throws -> URL

    public init(
        fetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCaseProtocol,
        upsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCaseProtocol,
        deleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCaseProtocol,
        uploadPaymentQr: @escaping (UIImage) async throws -> URL
    ) {
        self.fetchMyPaymentProfileUseCase = fetchMyPaymentProfileUseCase
        self.upsertMyPaymentProfileUseCase = upsertMyPaymentProfileUseCase
        self.deleteMyPaymentProfileUseCase = deleteMyPaymentProfileUseCase
        self.uploadPaymentQr = uploadPaymentQr
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try await fetchMyPaymentProfileUseCase.execute()
            apply(profile)
        } catch {
            clearForm()
        }
    }

    func uploadQrImage(_ image: UIImage) async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let url = try await uploadPaymentQr(image)
            qrImageURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try PaymentProfileFormValidator.validate(
                qrImageUrl: qrImageURL?.absoluteString,
                accountName: accountName,
                accountNumber: accountNumber,
                bankName: bankName
            )
            let profile = try await upsertMyPaymentProfileUseCase.execute(
                UpsertPaymentProfileInput(
                    qrImageUrl: qrImageURL?.absoluteString,
                    accountName: nilIfEmpty(accountName),
                    accountNumber: nilIfEmpty(accountNumber),
                    bankName: nilIfEmpty(bankName)
                )
            )
            apply(profile)
            return true
        } catch let formError as PaymentProfileFormError {
            errorMessage = formError.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteProfile() async -> Bool {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }

        do {
            try await deleteMyPaymentProfileUseCase.execute()
            clearForm()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var hasSavedProfile: Bool {
        qrImageURL != nil
            || !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func apply(_ profile: PaymentProfile) {
        qrImageURL = profile.qrImageURL
        accountName = profile.accountName ?? ""
        accountNumber = profile.accountNumber ?? ""
        bankName = profile.bankName ?? ""
    }

    private func clearForm() {
        qrImageURL = nil
        accountName = ""
        accountNumber = ""
        bankName = ""
    }

    private func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
