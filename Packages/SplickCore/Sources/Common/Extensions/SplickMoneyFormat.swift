import Foundation

/// Locale-independent money digits for Splick: thousands `,`, decimal `.`
/// (e.g. `1,250,000` / `1,234.56`). Language copy still follows `AppLocale`.
public enum SplickMoneyFormat {
    public static let groupingSeparator = ","
    public static let decimalSeparator = "."

    public static func numberFormatter(maxFractionDigits: Int = 0) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = groupingSeparator
        formatter.decimalSeparator = decimalSeparator
        formatter.groupingSize = 3
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = 0
        return formatter
    }

    public static func string(from amount: Decimal, maxFractionDigits: Int = 0) -> String {
        numberFormatter(maxFractionDigits: maxFractionDigits)
            .string(from: amount as NSDecimalNumber) ?? "0"
    }
}
