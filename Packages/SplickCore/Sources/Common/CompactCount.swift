import Foundation

/// Compact counts for feed badges: exact through 999, then `1k` / `1.5k` / `100k`.
public enum CompactCount {
    public static func format(_ count: Int) -> String {
        let value = max(count, 0)
        if value < 1_000 {
            return String(value)
        }
        if value < 1_000_000 {
            return scaled(value, divisor: 1_000, suffix: "k")
        }
        return scaled(value, divisor: 1_000_000, suffix: "m")
    }

    private static func scaled(_ value: Int, divisor: Int, suffix: String) -> String {
        let tenths = Int((Double(value) * 10.0 / Double(divisor)).rounded())
        if tenths % 10 == 0 {
            return "\(tenths / 10)\(suffix)"
        }
        return String(format: "%d.%d%@", tenths / 10, tenths % 10, suffix)
    }
}
