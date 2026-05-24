import Foundation

public enum AppConstants {
    public enum API {
        /// Gateway root (no version). Endpoints append `/v1/{domain}/...` — see `docs/API_ROUTING.md`.
        #if DEBUG
        public static let baseURL = "http://localhost:8080/api"
        #else
        public static let baseURL = "https://api.splick.app/api"
        #endif

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
    }

    public enum Media {
        public static let maxImageSizeBytes: Int = 10 * 1024 * 1024 // 10 MB (posts; future)
        public static let maxAvatarSizeBytes: Int = 5 * 1024 * 1024 // 5 MB — matches media-service USER_AVATAR
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
}
