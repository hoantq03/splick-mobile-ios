import Foundation

public enum AppConstants {
    /// When true, feed/expense/notification use in-memory fakes. Auth always calls the live API.
    public enum Dev {
        #if DEBUG
        public static let useMockData = true
        #else
        public static let useMockData = false
        #endif
    }

    public enum API {
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
        public static let serviceName = "com.splick.keychain"
    }

    public enum UserDefaults {
        public static let isOnboardingCompleted = "isOnboardingCompleted"
        public static let lastSyncTimestamp = "lastSyncTimestamp"
        public static let selectedTheme = "selectedTheme"
        public static let pushNotificationsEnabled = "pushNotificationsEnabled"
    }

    public enum Media {
        public static let maxImageSizeBytes: Int = 10 * 1024 * 1024 // 10 MB
        public static let thumbnailSize: CGFloat = 200
        public static let compressionQuality: CGFloat = 0.8
        public static let supportedFormats = ["jpeg", "png", "heic"]
    }

    public enum Validation {
        public static let minPasswordLength = 8
        public static let maxPasswordLength = 128
        public static let maxUsernameLength = 30
        public static let maxGroupNameLength = 50
        public static let maxExpenseDescriptionLength = 200
    }
}
