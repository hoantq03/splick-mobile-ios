import Foundation
import SwiftUI

enum VNDMoneyFormat {
    private static let displayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static func format(_ amount: Decimal) -> String {
        displayFormatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    static func formatDisplay(_ amount: Decimal, currency: String = "đ") -> String {
        "\(format(amount)) \(currency)"
    }

    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "đ", with: "")
            .replacingOccurrences(of: "VND", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Decimal(string: cleaned)
    }

    /// Keeps digits only, formats with "." grouping while typing.
    static func sanitizedInput(from raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        guard let value = Decimal(string: digits) else { return raw.filter(\.isNumber) }
        return format(value)
    }

    static func moneyBinding(_ storage: Binding<String>) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { storage.wrappedValue = sanitizedInput(from: $0) }
        )
    }

    static func percentBinding(_ storage: Binding<String>) -> Binding<String> {
        Binding(
            get: { storage.wrappedValue },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber || $0 == "," || $0 == "." }
                storage.wrappedValue = filtered
            }
        )
    }

    static func parsePercent(_ text: String) -> Decimal? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: normalized)
    }
}
