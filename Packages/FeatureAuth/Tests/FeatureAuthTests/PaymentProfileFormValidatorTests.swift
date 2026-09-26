import XCTest
@testable import FeatureAuth

final class PaymentProfileFormValidatorTests: XCTestCase {

    func testValidate_withValidQrOnly_succeeds() {
        XCTAssertNoThrow(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: "https://example.com/qr.png",
                accountName: nil,
                accountNumber: nil,
                bankName: nil
            )
        )
    }

    func testValidate_withCompleteBankDetailsOnly_succeeds() {
        XCTAssertNoThrow(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: nil,
                accountName: "NGUYEN VAN A",
                accountNumber: "1234567890",
                bankName: "Techcombank"
            )
        )
    }

    func testValidate_withBothQrAndCompleteBankDetails_succeeds() {
        XCTAssertNoThrow(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: "https://example.com/qr.png",
                accountName: "NGUYEN VAN A",
                accountNumber: "1234567890",
                bankName: "Techcombank"
            )
        )
    }

    func testValidate_withNeitherQrNorBankDetails_throwsMissingRequiredSet() {
        XCTAssertThrowsError(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: nil,
                accountName: nil,
                accountNumber: nil,
                bankName: nil
            )
        ) { error in
            guard let formError = error as? PaymentProfileFormError else {
                return XCTFail("Expected PaymentProfileFormError, got \(error)")
            }
            XCTAssertEqual(formError, .missingRequiredSet)
            XCTAssertEqual(
                formError.errorDescription,
                "Provide a QR image or complete bank account details."
            )
        }
    }

    func testValidate_withIncompleteBankDetails_throwsIncompleteBankSet() {
        // Only account name
        XCTAssertThrowsError(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: nil,
                accountName: "NGUYEN VAN A",
                accountNumber: nil,
                bankName: nil
            )
        ) { error in
            XCTAssertEqual(error as? PaymentProfileFormError, .incompleteBankSet)
        }

        // Only account number
        XCTAssertThrowsError(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: nil,
                accountName: nil,
                accountNumber: "123456",
                bankName: nil
            )
        ) { error in
            XCTAssertEqual(error as? PaymentProfileFormError, .incompleteBankSet)
        }

        // Account name and number, missing bank name
        XCTAssertThrowsError(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: nil,
                accountName: "NGUYEN VAN A",
                accountNumber: "123456",
                bankName: "   "
            )
        ) { error in
            XCTAssertEqual(error as? PaymentProfileFormError, .incompleteBankSet)
            XCTAssertEqual(
                (error as? PaymentProfileFormError)?.errorDescription,
                "Account name, account number, and bank name must all be provided together."
            )
        }
    }

    func testValidate_withInvalidAccountNumber_throwsInvalidAccountNumber() {
        XCTAssertThrowsError(
            try PaymentProfileFormValidator.validate(
                qrImageUrl: nil,
                accountName: "NGUYEN VAN A",
                accountNumber: "1234ABC56",
                bankName: "MBBank"
            )
        ) { error in
            XCTAssertEqual(error as? PaymentProfileFormError, .invalidAccountNumber)
            XCTAssertEqual(
                (error as? PaymentProfileFormError)?.errorDescription,
                "Account number must contain digits only."
            )
        }
    }
}
