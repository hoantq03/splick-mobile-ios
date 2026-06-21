import Foundation

extension UserSession {
    public var deviceKind: SessionDeviceKind {
        SessionDeviceKind.detect(deviceName: deviceName, deviceInfo: deviceInfo)
    }

    /// Primary line — hardware name when available (e.g. "iPhone 16 Pro").
    public var displayTitle: String {
        if let parsed = parsedDeviceInfoComponents {
            if !parsed.hardware.isEmpty, parsed.hardware != "Unknown device" {
                return parsed.hardware
            }
        }
        if let deviceName, !deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() != "iphone" && trimmed.lowercased() != "ipad" {
                return trimmed
            }
        }
        return displayDevice
    }

    /// Secondary line — OS / platform (e.g. "iOS 18.2").
    public var displayPlatform: String? {
        if let parsed = parsedDeviceInfoComponents, let platform = parsed.platform, !platform.isEmpty {
            return platform
        }
        return inferredPlatform(from: deviceName) ?? inferredPlatform(from: deviceInfo)
    }

    public var displayLocationLine: String? {
        let location = loginLocation?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ip = loginIp?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (location?.isEmpty == false ? location : nil, ip?.isEmpty == false ? ip : nil) {
        case let (loc?, ip?):
            return "\(loc) · \(ip)"
        case let (loc?, nil):
            return loc
        case let (nil, ip?):
            return ip
        case (nil, nil):
            return nil
        }
    }

    private var parsedDeviceInfoComponents: (hardware: String, platform: String?)? {
        guard let deviceInfo else { return nil }
        let trimmed = deviceInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed
            .split(separator: "·", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let hardware = parts.first, !hardware.isEmpty else { return nil }
        let platform = parts.count > 1 ? parts.dropFirst().joined(separator: " · ") : nil
        return (hardware, platform?.isEmpty == false ? platform : nil)
    }

    private func inferredPlatform(from value: String?) -> String? {
        guard let value else { return nil }
        let lower = value.lowercased()
        if let range = lower.range(of: "ios ") {
            return String(value[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = lower.range(of: "ipados ") {
            return String(value[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if lower.contains("macos") || lower.contains("mac os") {
            return value
        }
        if lower.contains("android") {
            return value
        }
        if lower.contains("windows") {
            return value
        }
        return nil
    }
}
