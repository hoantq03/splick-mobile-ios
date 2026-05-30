import Foundation

public enum SplickQRAction: Equatable {
    case addFriend(username: String)
    /// Server-issued personal QR (`POST /v1/social/qr/me` payload, base64url JSON).
    case addFriendByServerPayload(String)
    case joinGroup(inviteCode: String)
}

public enum SplickQRParser {
    public static func parse(_ raw: String) -> SplickQRAction? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value), url.scheme?.lowercased() == "splick" {
            let host = (url.host ?? "").lowercased()
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if host == "friend", !path.isEmpty {
                return .addFriend(username: path)
            }
            if host == "group", !path.isEmpty {
                return .joinGroup(inviteCode: path)
            }
        }

        if let serverPayload = parseServerPersonalPayload(value) {
            return .addFriendByServerPayload(serverPayload)
        }

        let lower = value.lowercased()
        if lower.hasPrefix("friend:") {
            let username = String(value.dropFirst("friend:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return username.isEmpty ? nil : .addFriend(username: username)
        }
        if lower.hasPrefix("group:") {
            let code = String(value.dropFirst("group:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return code.isEmpty ? nil : .joinGroup(inviteCode: code)
        }

        return nil
    }

    public static func friendPayload(username: String) -> String {
        "splick://friend/\(username)"
    }

    public static func groupPayload(inviteCode: String) -> String {
        "splick://group/\(inviteCode)"
    }

    /// Returns the raw scanned string when it is a server-issued personal QR envelope.
    private static func parseServerPersonalPayload(_ raw: String) -> String? {
        guard let data = base64URLDecode(raw),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "user",
              json["userId"] != nil,
              json["qrVersion"] != nil,
              json["nonce"] != nil
        else {
            return nil
        }
        return raw
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}
