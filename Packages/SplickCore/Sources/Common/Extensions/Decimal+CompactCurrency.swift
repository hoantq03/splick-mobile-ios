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
