import Foundation

/// Opaque keyset cursor matching expense-service `ExpenseCursorCodec`
/// (`Base64URL(createdAt|expenseId)` without padding).
enum ExpenseListCursor {
  static func encode(createdAt: Date, expenseId: UUID) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var iso = formatter.string(from: createdAt)
    // Java Instant.toString() omits fractional seconds when zero.
    if iso.hasSuffix(".000Z") {
      iso = String(iso.dropLast(5)) + "Z"
    }
    let raw = "\(iso)|\(expenseId.uuidString.lowercased())"
    return Data(raw.utf8).base64URLEncodedString()
  }
}

private extension Data {
  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
