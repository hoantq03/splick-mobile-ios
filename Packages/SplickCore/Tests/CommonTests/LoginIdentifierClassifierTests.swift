import Testing
@testable import Common

struct LoginIdentifierClassifierTests {
    @Test
    func lettersWithoutAtAreIncompleteEmail() {
        let result = LoginIdentifierClassifier.classify("hoan")
        #expect(result == .email(.incomplete))
    }

    @Test
    func atSignSwitchesToEmailValidation() {
        #expect(LoginIdentifierClassifier.classify("hoan@") == .email(.invalid))
        #expect(LoginIdentifierClassifier.classify("hoan@splick.app") == .email(.valid))
    }

    @Test
    func localVietnamMobileDefaultsToVietnam() {
        let result = LoginIdentifierClassifier.classify("0901234567")
        guard case .phone(let parsed) = result else {
            Issue.record("Expected phone classification")
            return
        }
        #expect(parsed.region == .vietnam)
        #expect(parsed.e164 == "+84901234567")
        #expect(parsed.completeness == .complete)
    }

    @Test
    func incompleteLocalVietnamNumberDoesNotFail() {
        let result = LoginIdentifierClassifier.classify("09")
        guard case .phone(let parsed) = result else {
            Issue.record("Expected phone classification")
            return
        }
        #expect(parsed.region == .vietnam)
        #expect(parsed.completeness == .incomplete)
    }

    @Test
    func plusPrefixDetectsCountryCallingCode() {
        let result = LoginIdentifierClassifier.classify("+12025550123")
        guard case .phone(let parsed) = result else {
            Issue.record("Expected phone classification")
            return
        }
        #expect(parsed.region.isoRegionCode == "US")
        #expect(parsed.region.callingCode == "1")
        #expect(parsed.e164 == "+12025550123")
        #expect(parsed.completeness == .complete)
    }

    @Test
    func internationalExitCodeIsTreatedAsPlus() {
        let result = LoginIdentifierClassifier.classify("0084901234567")
        guard case .phone(let parsed) = result else {
            Issue.record("Expected phone classification")
            return
        }
        #expect(parsed.region == .vietnam)
        #expect(parsed.e164 == "+84901234567")
    }

    @Test
    func stripsVietnamTrunkZeroAndKeepsNationalNumber() {
        let stripped = PhoneNumberParser.normalizeTypedIdentifier("0901234567", selectedRegion: .vietnam)
        #expect(stripped?.region == .vietnam)
        #expect(stripped?.displayText == "901234567")

        let kept = PhoneNumberParser.normalizeTypedIdentifier("901234567", selectedRegion: .vietnam)
        #expect(kept?.region == .vietnam)
        #expect(kept?.displayText == "901234567")

        let loneZero = PhoneNumberParser.normalizeTypedIdentifier("0", selectedRegion: .vietnam)
        #expect(loneZero?.displayText == "0")
    }

    @Test
    func leavesEmailTypingUnchanged() {
        #expect(PhoneNumberParser.normalizeTypedIdentifier("hoan", selectedRegion: .vietnam) == nil)
        #expect(PhoneNumberParser.normalizeTypedIdentifier("hoan@splick.app", selectedRegion: .vietnam) == nil)
    }
}
