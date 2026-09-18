import Foundation
import SplickDomain
import UIKit
import DesignSystem

@MainActor
public final class PaymentProfileManageViewModel: ObservableObject {
    @Published var qrImageURL: URL?
    @Published var accountName = ""
    @Published var accountNumber = ""
    @Published var bankName = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
    @Published var isUploadingQr = false
    @Published var qrUploadPreview: UIImage?
    @Published var errorMessage: String?
    @Published var showDeleteConfirm = false

    private var savedSnapshot = FormSnapshot()

    private let fetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCaseProtocol
    private let upsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCaseProtocol
    private let deleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCaseProtocol
    private let uploadPaymentQr: (UIImage) async throws -> URL
    private let onProfileChanged: ((PaymentProfile?) -> Void)?

    public init(
        fetchMyPaymentProfileUseCase: FetchMyPaymentProfileUseCaseProtocol,
        upsertMyPaymentProfileUseCase: UpsertMyPaymentProfileUseCaseProtocol,
        deleteMyPaymentProfileUseCase: DeleteMyPaymentProfileUseCaseProtocol,
        uploadPaymentQr: @escaping (UIImage) async throws -> URL,
        onProfileChanged: ((PaymentProfile?) -> Void)? = nil
    ) {
        self.fetchMyPaymentProfileUseCase = fetchMyPaymentProfileUseCase
        self.upsertMyPaymentProfileUseCase = upsertMyPaymentProfileUseCase
        self.deleteMyPaymentProfileUseCase = deleteMyPaymentProfileUseCase
        self.uploadPaymentQr = uploadPaymentQr
        self.onProfileChanged = onProfileChanged
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
        qrUploadPreview = image
        isUploadingQr = true
        errorMessage = nil
        let started = ContinuousClock.now
        do {
            let url = try await uploadPaymentQr(image)
            qrImageURL = url
        } catch {
            errorMessage = error.localizedDescription
        }
        await holdMinimumLoading(from: started)
        qrUploadPreview = nil
        isUploadingQr = false
    }

    func removeQrImage() {
        qrImageURL = nil
        qrUploadPreview = nil
        errorMessage = nil
    }

    func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        let started = ContinuousClock.now
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
            onProfileChanged?(profile.hasAnyContent ? profile : nil)
            await holdMinimumLoading(from: started)
            isSaving = false
            return true
        } catch let formError as PaymentProfileFormError {
            errorMessage = formError.localizedDescription
            await holdMinimumLoading(from: started)
            isSaving = false
            return false
        } catch {
            errorMessage = error.localizedDescription
            await holdMinimumLoading(from: started)
            isSaving = false
            return false
        }
    }

    func deleteProfile() async -> Bool {
        isDeleting = true
        errorMessage = nil
        let started = ContinuousClock.now
        do {
            try await deleteMyPaymentProfileUseCase.execute()
            clearForm()
            onProfileChanged?(nil)
            await holdMinimumLoading(from: started)
            isDeleting = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            await holdMinimumLoading(from: started)
            isDeleting = false
            return false
        }
    }

    var hasSavedProfile: Bool {
        qrImageURL != nil
            || !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !bankName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasUnsavedChanges: Bool {
        currentSnapshot != savedSnapshot
    }

    private func holdMinimumLoading(from started: ContinuousClock.Instant) async {
        let minimum = Duration.nanoseconds(Int64(SplickButton.minimumLoadingNanoseconds))
        let elapsed = started.duration(to: .now)
        if elapsed < minimum {
            try? await Task.sleep(for: minimum - elapsed)
        }
    }

    private func apply(_ profile: PaymentProfile) {
        qrImageURL = profile.qrImageURL
        accountName = profile.accountName ?? ""
        accountNumber = profile.accountNumber ?? ""
        bankName = profile.bankName ?? ""
        savedSnapshot = currentSnapshot
    }

    private func clearForm() {
        qrImageURL = nil
        qrUploadPreview = nil
        accountName = ""
        accountNumber = ""
        bankName = ""
        savedSnapshot = currentSnapshot
    }

    private var currentSnapshot: FormSnapshot {
        FormSnapshot(
            qrImageURL: qrImageURL?.absoluteString,
            accountName: accountName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountNumber: accountNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private struct FormSnapshot: Equatable {
        var qrImageURL: String?
        var accountName = ""
        var accountNumber = ""
        var bankName = ""
    }

    private func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
