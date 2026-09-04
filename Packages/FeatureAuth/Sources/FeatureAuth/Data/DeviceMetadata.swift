import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum DeviceMetadata {
    static var marketingName: String {
        #if canImport(UIKit)
        return marketingName(forMachineIdentifier: machineIdentifier)
            ?? UIDevice.current.model
        #else
        return "Splick"
        #endif
    }

    static var platformLine: String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        return "Splick"
        #endif
    }

    #if canImport(UIKit)
    static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    static func marketingName(forMachineIdentifier identifier: String) -> String? {
        machineDisplayNames[identifier]
    }

    private static let machineDisplayNames: [String: String] = [
        // iPhone 16 series
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        // iPhone 15 series
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        // iPhone 14 series
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        // iPhone 13 series
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        // iPhone 12 series
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        // iPhone SE
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone12,8": "iPhone SE (2nd generation)",
        // iPad Pro
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,4": "iPad Pro 13-inch (M4)",
        "iPad14,3": "iPad Pro 11-inch (M2)",
        "iPad14,4": "iPad Pro 12.9-inch (M2)",
        // iPad Air / mini
        "iPad14,8": "iPad Air (5th generation)",
        "iPad14,9": "iPad Air (5th generation)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",
        // Simulators
        "i386": "Simulator",
        "x86_64": "Simulator",
        "arm64": "Simulator",
    ]
    #endif
}
