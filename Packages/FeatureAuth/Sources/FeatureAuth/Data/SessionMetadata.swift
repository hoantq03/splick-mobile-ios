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

    /// Fallback when the server cannot geolocate the login IP (local/dev).
    static var loginLocation: String? {
        var parts: [String] = []
        let zone = TimeZone.current.identifier.replacingOccurrences(of: "_", with: " ")
        if let city = zone.split(separator: "/").last, !city.isEmpty {
            parts.append(String(city))
        }
        if let region = Locale.current.region?.identifier {
            let country = Locale.current.localizedString(forRegionCode: region) ?? region
            if parts.contains(where: { $0.caseInsensitiveCompare(country) == .orderedSame }) == false {
                parts.append(country)
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct ClientSessionPayload: Encodable {
    let deviceInfo: String
    let deviceName: String
    let loginLocation: String?
}
