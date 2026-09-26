import Foundation

public enum WidgetCurrencyFormatter {
    public static func string(from amount: Decimal, currency: String = "VND") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = currency == "VND" ? 0 : 2
        formatter.minimumFractionDigits = currency == "VND" ? 0 : 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let numeric = NSDecimalNumber(decimal: amount)
        let formatted = formatter.string(from: numeric) ?? numeric.stringValue
        switch currency.uppercased() {
        case "VND":
            return "\(formatted)₫"
        case "USD":
            return "$\(formatted)"
        default:
            return "\(formatted) \(currency)"
        }
    }

    public static func signedString(from amount: Decimal, currency: String = "VND") -> String {
        if amount > 0 {
            return "+\(string(from: amount, currency: currency))"
        }
        if amount < 0 {
            return "-\(string(from: abs(amount), currency: currency))"
        }
        return string(from: .zero, currency: currency)
    }

    public static func decimal(from string: String) -> Decimal {
        Decimal(string: string) ?? .zero
    }
}

public enum WidgetRelativeDateFormatter {
    public static func shortString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
