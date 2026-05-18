import Foundation

public enum SplickQRAction: Equatable {
    case addFriend(username: String)
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
}
