import Foundation

public enum SplickQRAction: Equatable {
    case addFriend(username: String)
    /// Server-issued personal QR (`POST /v1/social/qr/me` payload, base64url JSON).
    case addFriendByServerPayload(String)
    case joinGroup(inviteCode: String)
    /// Server-issued group QR (`POST /v1/groups/{id}/qr` payload, base64url JSON).
    case joinGroupByServerPayload(String)
}

public enum SplickQRParser {
    private static let webHost = "splick.app"

    public static func parse(_ raw: String) -> SplickQRAction? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value) {
            let scheme = url.scheme?.lowercased()
            let host = (url.host ?? "").lowercased()
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            if scheme == "splick" {
                if host == "friend", !path.isEmpty {
                    return .addFriend(username: path)
                }
                if host == "group", !path.isEmpty {
                    return .joinGroup(inviteCode: path)
                }
            }

            if scheme == "https" || scheme == "http" {
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let qrPayload = components?.queryItems?.first(where: { item in
                    let name = item.name.lowercased()
                    return name == "qr" || name == "payload"
                })?.value
                let pathComponents = path
                    .split(separator: "/")
                    .map(String.init)
                    .filter { !$0.isEmpty }

                if host == webHost || host == "www.\(webHost)" {
                    if pathComponents.count == 2,
                       pathComponents[0].lowercased() == "group",
                       pathComponents[1].lowercased() == "join",
                       let qrPayload,
                       !qrPayload.isEmpty {
                        return .joinGroupByServerPayload(qrPayload)
                    }
                    if pathComponents.count == 2, pathComponents[0].lowercased() == "group" {
                        return .joinGroup(inviteCode: pathComponents[1])
                    }
                    if pathComponents.count == 2, pathComponents[0].lowercased() == "friend" {
                        return .addFriend(username: pathComponents[1])
                    }
                    if pathComponents.count == 1 {
                        return .addFriend(username: pathComponents[0])
                    }
                }
            }
        }

        if let serverPayload = parseServerPersonalPayload(value) {
            return .addFriendByServerPayload(serverPayload)
        }

        if let serverPayload = parseServerGroupPayload(value) {
            return .joinGroupByServerPayload(serverPayload)
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
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        if let type = json["type"] as? String,
           type == "user",
           json["userId"] != nil,
           json["qrVersion"] != nil,
           json["nonce"] != nil {
            return raw
        }
        if let type = json["t"] as? String,
           type == "u",
           json["i"] != nil,
           json["q"] != nil,
           json["n"] != nil {
            return raw
        }
        return nil
    }

    /// Returns the raw scanned string when it is a server-issued group QR envelope.
    private static func parseServerGroupPayload(_ raw: String) -> String? {
        guard let data = base64URLDecode(raw),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        if let type = json["type"] as? String,
           type == "group",
           json["groupId"] != nil,
           json["nonce"] != nil,
           json["issuedAt"] != nil {
            return raw
        }
        if let type = json["t"] as? String,
           type == "g",
           json["i"] != nil,
           json["n"] != nil {
            return raw
        }
        return nil
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
