import Foundation

public enum AppConstants {
    public enum API {
        /// Gateway root (no version). Endpoints append `/v1/{domain}/...` — see `docs/API_ROUTING.md`.
        /// Production: Cloudflare HTTPS → VPS :80 → Kong. `/api` is the Kong path prefix (not a port).
        /// Full URL example: `https://api.splick.app/api` + `/v1/auth/login`
        /// Local Mac backend: `http://localhost:8080/api`
        public static let baseURL = "https://api.splick.app/api"

        /// WebSocket base URL — derived from `baseURL` so local dev automatically uses `ws://`.
        public static var wsBaseURL: String {
            baseURL
                .replacingOccurrences(of: "https://", with: "wss://")
                .replacingOccurrences(of: "http://", with: "ws://")
        }

        public static let timeoutInterval: TimeInterval = 30
        public static let maxRetryCount = 3
        public static let paginationDefaultLimit = 20
    }

    public enum Keychain {
        public static let accessTokenKey = "com.splick.accessToken"
        public static let refreshTokenKey = "com.splick.refreshToken"
        public static let userIdKey = "com.splick.userId"
        public static let sessionIdKey = "com.splick.sessionId"
        public static let serviceName = "com.splick.keychain"
    }

    public enum UserDefaults {
        public static let isOnboardingCompleted = "isOnboardingCompleted"
        public static let lastSyncTimestamp = "lastSyncTimestamp"
        public static let selectedTheme = "selectedTheme"
        public static let pushNotificationsEnabled = "pushNotificationsEnabled"
        public static let preferredLocale = "preferredLocale"
    }

    public enum Media {
        public static let maxImageSizeBytes: Int = 10 * 1024 * 1024 // 10 MB (posts; future)
        public static let maxAvatarSizeBytes: Int = 5 * 1024 * 1024 // 5 MB — matches media-service USER_AVATAR
        public static let maxCustomEmojiSizeBytes: Int = 2 * 1024 * 1024 // 2 MB — matches GROUP_CUSTOM_EMOJI
        public static let thumbnailSize: CGFloat = 200
        public static let compressionQuality: CGFloat = 0.8
        public static let supportedFormats = ["jpeg", "png", "heic"]
    }

    public enum Validation {
        public static let minPasswordLength = 8
        public static let maxPasswordLength = 100
        public static let maxUsernameLength = 50
        public static let maxGroupNameLength = 50
        public static let maxExpenseDescriptionLength = 200
    }

    public enum Giphy {
        /// Read from `GIPHY_API_KEY` in Info.plist (inject via xcconfig / CI secret — never commit production keys).
        public static var apiKey: String {
            Bundle.main.object(forInfoDictionaryKey: "GIPHY_API_KEY") as? String ?? ""
        }

        public static let baseURL = "https://api.giphy.com/v1/gifs"
        public static let defaultPageLimit = 25
        public static let searchDebounceMilliseconds = 500
        public static let attributionURL = URL(string: "https://giphy.com")!
    }

    public enum Stickers {
        public static let maxGifsPerComment = 5
    }

    public enum Splash {
        public static let minimumDisplayDuration: Duration = .milliseconds(1500)
        public static let dismissDuration: Duration = .milliseconds(850)
    }

    public enum Links {
        public static let webHost = "splick.app"

        public static func profileInvitePath(username: String) -> String {
            "\(webHost)/\(username)"
        }

        public static func profileInviteURL(username: String) -> URL {
            URL(string: "https://\(profileInvitePath(username: username))")!
        }

        public static let marketingURL = URL(string: "https://\(webHost)")!
        public static let termsOfServiceURL = URL(string: "https://\(webHost)/terms")!
        public static let privacyPolicyURL = URL(string: "https://\(webHost)/privacy")!
    }
}
