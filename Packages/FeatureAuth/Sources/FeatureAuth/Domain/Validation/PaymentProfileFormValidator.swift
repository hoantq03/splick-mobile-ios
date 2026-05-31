import Foundation

enum PaymentProfileFormValidator {
    static func validate(
        qrImageUrl: String?,
        accountName: String?,
        accountNumber: String?,
        bankName: String?
    ) throws {
        let qr = normalize(qrImageUrl)
        let name = normalize(accountName)
        let number = normalize(accountNumber)
        let bank = normalize(bankName)

        let hasQr = qr != nil
        let hasName = name != nil
        let hasNumber = number != nil
        let hasBank = bank != nil
        let hasCompleteBank = hasName && hasNumber && hasBank
        let hasPartialBank = hasName || hasNumber || hasBank

        if hasPartialBank && !hasCompleteBank {
            throw PaymentProfileFormError.incompleteBankSet
        }
        if !hasQr && !hasCompleteBank {
            throw PaymentProfileFormError.missingRequiredSet
        }
        if let number, !number.allSatisfy(\.isNumber) {
            throw PaymentProfileFormError.invalidAccountNumber
        }
    }

    private static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum PaymentProfileFormError: LocalizedError {
    case incompleteBankSet
    case missingRequiredSet
    case invalidAccountNumber

    var errorDescription: String? {
        switch self {
        case .incompleteBankSet:
            return "Account name, account number, and bank name must all be provided together."
        case .missingRequiredSet:
            return "Provide a QR image or complete bank account details."
        case .invalidAccountNumber:
            return "Account number must contain digits only."
        }
    }
}
