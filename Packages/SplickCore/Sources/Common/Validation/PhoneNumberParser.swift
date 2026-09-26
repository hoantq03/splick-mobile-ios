import Foundation

public struct ParsedPhoneNumber: Equatable, Sendable {
    public enum Completeness: Equatable, Sendable {
        case incomplete
        case complete
        case invalid
    }

    public let region: PhoneCallingRegion
    public let e164Candidate: String
    public let completeness: Completeness

    public var e164: String? {
        completeness == .complete ? e164Candidate : nil
    }
}

public enum PhoneNumberParser {
    private static let e164MinDigits = 8
    private static let e164MaxDigits = 15
    private static let vietnamNationalLength = 9
    private static let vietnamLocalLengthWithTrunk = 10
    private static let vietnamWithCountryCodeLength = 11

    public static func parse(
        _ raw: String,
        defaultRegion: PhoneCallingRegion = .vietnam
    ) -> ParsedPhoneNumber? {
        let compact = compactPhone(raw)
        guard looksLikePhone(compact) else { return nil }

        if compact.hasPrefix("+") || compact.hasPrefix("00") {
            return parseInternational(compact, defaultRegion: defaultRegion)
        }

        return parseNational(compact, defaultRegion: defaultRegion)
    }

    public static func looksLikePhone(_ raw: String) -> Bool {
        looksLikePhoneCompact(compactPhone(raw))
    }

    /// Rewrites phone typing into national digits for the selected country.
    /// Strips a leading trunk `0`. Email-like input is left unchanged (`nil`).
    public static func normalizeTypedIdentifier(
        _ raw: String,
        selectedRegion: PhoneCallingRegion
    ) -> (region: PhoneCallingRegion, displayText: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("@") || trimmed.contains(where: \.isLetter) {
            return nil
        }

        let compact = compactPhone(trimmed)
        guard looksLikePhoneCompact(compact) else { return nil }

        if compact.hasPrefix("+") || compact.hasPrefix("00") {
            let digits: String
            if compact.hasPrefix("+") {
                digits = String(compact.dropFirst().filter(\.isNumber))
            } else {
                digits = String(compact.dropFirst(2).filter(\.isNumber))
            }
            guard !digits.isEmpty else { return nil }
            guard let region = PhoneCallingCodeTable.region(forDigits: digits) else {
                return nil
            }
            let national = String(digits.dropFirst(region.callingCode.count))
            return (region, national)
        }

        var digits = String(compact.filter(\.isNumber))
        if digits.hasPrefix("0"), digits.count >= 2 {
            digits = String(digits.dropFirst())
        }
        return (selectedRegion, digits)
    }

    private static func parseInternational(
        _ compact: String,
        defaultRegion: PhoneCallingRegion
    ) -> ParsedPhoneNumber {
        let digits: String
        if compact.hasPrefix("+") {
            digits = String(compact.dropFirst().filter(\.isNumber))
        } else {
            digits = String(compact.dropFirst(2).filter(\.isNumber))
        }

        guard !digits.isEmpty else {
            return ParsedPhoneNumber(
                region: defaultRegion,
                e164Candidate: "+",
                completeness: .incomplete
            )
        }

        let region = PhoneCallingCodeTable.region(forDigits: digits) ?? defaultRegion
        let e164Candidate = "+" + digits
        return ParsedPhoneNumber(
            region: region,
            e164Candidate: e164Candidate,
            completeness: completeness(forE164Digits: digits)
        )
    }

    private static func parseNational(
        _ compact: String,
        defaultRegion: PhoneCallingRegion
    ) -> ParsedPhoneNumber {
        let digits = String(compact.filter(\.isNumber))
        let region = defaultRegion

        if digits.hasPrefix(region.callingCode), digits.count >= vietnamWithCountryCodeLength {
            return ParsedPhoneNumber(
                region: region,
                e164Candidate: "+" + digits,
                completeness: completeness(forE164Digits: digits)
            )
        }

        let nationalDigits: String
        if digits.hasPrefix("0") {
            nationalDigits = String(digits.dropFirst())
        } else {
            nationalDigits = digits
        }

        let e164Candidate = "+" + region.callingCode + nationalDigits
        let e164Digits = region.callingCode + nationalDigits

        if digits.hasPrefix("0") {
            if digits.count < vietnamLocalLengthWithTrunk {
                return ParsedPhoneNumber(
                    region: region,
                    e164Candidate: e164Candidate,
                    completeness: .incomplete
                )
            }
            if digits.count > vietnamLocalLengthWithTrunk {
                return ParsedPhoneNumber(
                    region: region,
                    e164Candidate: e164Candidate,
                    completeness: .invalid
                )
            }
            return ParsedPhoneNumber(
                region: region,
                e164Candidate: e164Candidate,
                completeness: completeness(forE164Digits: e164Digits)
            )
        }

        if digits.count < vietnamNationalLength {
            return ParsedPhoneNumber(
                region: region,
                e164Candidate: e164Candidate,
                completeness: .incomplete
            )
        }
        if digits.count > vietnamNationalLength {
            return ParsedPhoneNumber(
                region: region,
                e164Candidate: e164Candidate,
                completeness: .invalid
            )
        }
        return ParsedPhoneNumber(
            region: region,
            e164Candidate: e164Candidate,
            completeness: completeness(forE164Digits: e164Digits)
        )
    }

    private static func completeness(forE164Digits digits: String) -> ParsedPhoneNumber.Completeness {
        if digits.count < e164MinDigits {
            return .incomplete
        }
        if digits.count > e164MaxDigits {
            return .invalid
        }
        return ("+" + digits).isValidE164Phone ? .complete : .invalid
    }

    private static func compactPhone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var compact = ""
        compact.reserveCapacity(trimmed.count)
        for character in trimmed {
            if character.isNumber || character == "+" {
                compact.append(character)
            } else if character == " " || character == "-" || character == "(" || character == ")"
                || character == "." || character == "\u{00a0}"
            {
                continue
            } else {
                compact.append(character)
            }
        }
        return compact
    }

    private static func looksLikePhoneCompact(_ compact: String) -> Bool {
        guard !compact.isEmpty else { return false }
        if compact.hasPrefix("+") {
            return compact.dropFirst().allSatisfy(\.isNumber) || compact == "+"
        }
        if compact.hasPrefix("00") {
            return compact.dropFirst(2).allSatisfy(\.isNumber)
        }
        return compact.allSatisfy(\.isNumber)
    }
}
