import Foundation

public extension Decimal {
    /// Compact amount for list rows — e.g. 125_000 → `125K`, 1_500_000 → `1.5M`.
    func compactAmountString() -> String {
        Self.compactAmountString(for: self)
    }

    static func compactAmountString(for amount: Decimal) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let sign = value < 0 ? "-" : ""
        let absolute = abs(value)

        if absolute >= 1_000_000 {
            return sign + formatCompactUnit(absolute / 1_000_000, suffix: "M")
        }
        if absolute >= 1_000 {
            return sign + formatCompactUnit(absolute / 1_000, suffix: "K")
        }
        return sign + formatCompactUnit(absolute, suffix: "")
    }

    /// Short currency mark for tight UI — e.g. VND → `đ`, USD → `$`.
    static func displayCurrencySymbol(for currencyCode: String, locale: Locale = .current) -> String {
        switch currencyCode.uppercased() {
        case "VND":
            return "đ"
        case "USD":
            return "$"
        default:
            return currencySymbol(for: currencyCode, locale: locale)
        }
    }

    /// Full digit amount with currency symbol for chart centers — e.g. `1.250.000đ`, `$1,250`.
    /// Shows up to 10 integer digits; larger values fall back to compact `K`/`M` form.
    func chartAmountString(currencyCode: String = "VND", locale: Locale = .current) -> String {
        Self.chartAmountString(for: self, currencyCode: currencyCode, locale: locale)
    }

    static func chartAmountString(
        for amount: Decimal,
        currencyCode: String = "VND",
        locale: Locale = .current
    ) -> String {
        let symbol = displayCurrencySymbol(for: currencyCode, locale: locale)
        let value = NSDecimalNumber(decimal: amount).doubleValue
        let sign = value < 0 ? "-" : ""
        let absolute = abs(value).rounded()
        let digitCount = absolute < 1 ? 1 : Int(floor(log10(absolute))) + 1

        let numberPart: String
        if digitCount > 10 {
            numberPart = compactAmountString(for: Decimal(absolute))
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = locale
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            formatter.usesGroupingSeparator = true
            numberPart = formatter.string(from: NSDecimalNumber(value: absolute))
                ?? String(format: "%.0f", absolute)
        }

        let signedNumber = sign + numberPart
        if currencyCode.uppercased() == "USD" {
            return "\(symbol)\(signedNumber)"
        }
        return "\(signedNumber)\(symbol)"
    }

    static func currencySymbol(for currencyCode: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.currencySymbol ?? currencyCode
    }

    private static func formatCompactUnit(_ value: Double, suffix: String) -> String {
        if suffix.isEmpty {
            return String(format: "%.0f", value.rounded())
        }

        if value >= 100 {
            return String(format: "%.0f%@", value.rounded(), suffix)
        }

        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded(.down) && rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f%@", rounded, suffix)
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}
