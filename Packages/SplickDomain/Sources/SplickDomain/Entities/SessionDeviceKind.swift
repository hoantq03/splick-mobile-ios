import Foundation

public enum SessionDeviceKind: String, Sendable, Equatable {
    case phone
    case tablet
    case laptop
    case desktop
    case watch
    case tv
    case unknown

    public var systemImageName: String {
        switch self {
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .desktop: return "desktopcomputer"
        case .watch: return "applewatch"
        case .tv: return "tv"
        case .unknown: return "desktopcomputer.and.arrow.down"
        }
    }

    public static func detect(deviceName: String?, deviceInfo: String?) -> SessionDeviceKind {
        let haystack = [deviceName, deviceInfo]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()

        guard !haystack.isEmpty else { return .unknown }

        if haystack.contains("ipad") || haystack.contains("tablet") {
            return .tablet
        }
        if haystack.contains("apple watch") || haystack.contains("watchos") {
            return .watch
        }
        if haystack.contains("apple tv") || haystack.contains("tvos") {
            return .tv
        }
        if haystack.contains("macbook") || haystack.contains("laptop") {
            return .laptop
        }
        if haystack.contains("imac")
            || haystack.contains("mac mini")
            || haystack.contains("mac studio")
            || haystack.contains("mac pro")
            || (haystack.contains("macos") && !haystack.contains("macbook")) {
            return .desktop
        }
        if haystack.contains("iphone")
            || haystack.contains("android")
            || haystack.contains("ios")
            || haystack.contains("mobile") {
            return .phone
        }
        if haystack.contains("windows") || haystack.contains("linux") || haystack.contains("chromeos") {
            return haystack.contains("laptop") ? .laptop : .desktop
        }
        return .unknown
    }
}

public enum SessionDeviceBrand: String, Sendable, Equatable {
    case apple
    case android
    case unknown

    public static func detect(deviceName: String?, deviceInfo: String?) -> SessionDeviceBrand {
        let haystack = [deviceName, deviceInfo]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()

        guard !haystack.isEmpty else { return .unknown }
        if haystack.contains("android") { return .android }
        if haystack.contains("iphone")
            || haystack.contains("ipad")
            || haystack.contains("ios")
            || haystack.contains("ipados")
            || haystack.contains("macos")
            || haystack.contains("mac os")
            || haystack.contains("apple") {
            return .apple
        }
        return .unknown
    }
}
