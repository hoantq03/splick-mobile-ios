import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum SessionMetadata {
    static var current: ClientSessionPayload {
        ClientSessionPayload(
            deviceInfo: deviceInfo,
            deviceName: deviceName,
            loginLocation: loginLocation
        )
    }

    static var deviceName: String {
        DeviceMetadata.marketingName
    }

    static var deviceInfo: String {
        "\(DeviceMetadata.marketingName) · \(DeviceMetadata.platformLine)"
    }

    /// Approximate location without GPS permission (region + timezone).
    static var loginLocation: String? {
        var parts: [String] = []
        if let region = Locale.current.region?.identifier {
            parts.append(Locale.current.localizedString(forRegionCode: region) ?? region)
        }
        let offset = TimeZone.current.secondsFromGMT()
        let hours = offset / 3600
        let sign = hours >= 0 ? "+" : ""
        parts.append("UTC\(sign)\(hours)")
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct ClientSessionPayload: Encodable {
    let deviceInfo: String
    let deviceName: String
    let loginLocation: String?
}
