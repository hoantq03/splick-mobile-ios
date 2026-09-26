import XCTest
@testable import SplickDomain

final class SessionDevicePresentationTests: XCTestCase {
    func testDeviceKindDetection() {
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: nil, deviceInfo: nil), .unknown)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "", deviceInfo: "   "), .unknown)
        
        // Tablet
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "iPad Pro 11", deviceInfo: "iPadOS 17.5"), .tablet)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Android Tablet", deviceInfo: ""), .tablet)
        
        // Watch
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Apple Watch Series 9", deviceInfo: "watchOS 10"), .watch)
        
        // TV
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Apple TV 4K", deviceInfo: "tvOS 17"), .tv)
        
        // Laptop
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "MacBook Pro 16", deviceInfo: "macOS 14"), .laptop)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Dell XPS", deviceInfo: "Windows 11 · Laptop"), .laptop)
        
        // Desktop
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "iMac 24", deviceInfo: ""), .desktop)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Mac Studio", deviceInfo: ""), .desktop)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Mac Mini M2", deviceInfo: ""), .desktop)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Mac Pro", deviceInfo: ""), .desktop)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Custom PC", deviceInfo: "macOS 14.5"), .desktop)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Workstation", deviceInfo: "Linux Ubuntu"), .desktop)
        
        // Phone
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "iPhone 15 Pro", deviceInfo: "iOS 17.5"), .phone)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Samsung Galaxy S24", deviceInfo: "Android 14"), .phone)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Pixel 8", deviceInfo: "Mobile"), .phone)
        XCTAssertEqual(SessionDeviceKind.detect(deviceName: "Unknown", deviceInfo: "random text"), .unknown)
    }

    func testDeviceBrandDetection() {
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: nil, deviceInfo: nil), .unknown)
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: "Pixel 8", deviceInfo: "Android 14"), .android)
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: "iPhone 14", deviceInfo: "iOS 16"), .apple)
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: "iPad Air", deviceInfo: "iPadOS"), .apple)
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: "MacBook Air", deviceInfo: "macOS"), .apple)
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: "Mac mini", deviceInfo: "Mac OS X"), .apple)
        XCTAssertEqual(SessionDeviceBrand.detect(deviceName: "ThinkPad", deviceInfo: "Windows 11"), .unknown)
    }

    func testSystemImageNames() {
        XCTAssertEqual(SessionDeviceKind.phone.systemImageName, "iphone")
        XCTAssertEqual(SessionDeviceKind.tablet.systemImageName, "ipad")
        XCTAssertEqual(SessionDeviceKind.laptop.systemImageName, "laptopcomputer")
        XCTAssertEqual(SessionDeviceKind.desktop.systemImageName, "desktopcomputer")
        XCTAssertEqual(SessionDeviceKind.watch.systemImageName, "applewatch")
        XCTAssertEqual(SessionDeviceKind.tv.systemImageName, "tv")
        XCTAssertEqual(SessionDeviceKind.unknown.systemImageName, "desktopcomputer.and.arrow.down")
    }

    func testUserSessionPresentation() {
        let now = Date()
        let session1 = UserSession(
            id: UUID(),
            deviceInfo: "iPhone 15 Pro · iOS 17.5",
            deviceName: "Hoan's iPhone",
            loginIp: "192.168.1.1",
            loginLocation: "Ho Chi Minh City",
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            isCurrent: true
        )

        XCTAssertEqual(session1.displayTitle, "iPhone 15 Pro")
        XCTAssertEqual(session1.displayPlatform, "iOS 17.5")
        XCTAssertEqual(session1.displayLocationLine, "Ho Chi Minh City · 192.168.1.1")
        XCTAssertEqual(session1.deviceKind, .phone)
        XCTAssertEqual(session1.deviceBrand, .apple)
        XCTAssertEqual(session1.displayDevice, "Hoan's iPhone")

        // Only location or only IP
        let sessionLocationOnly = UserSession(
            id: UUID(),
            deviceInfo: nil,
            deviceName: "Laptop",
            loginIp: nil,
            loginLocation: "Hanoi",
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            isCurrent: false
        )
        XCTAssertEqual(sessionLocationOnly.displayLocationLine, "Hanoi")

        let sessionIpOnly = UserSession(
            id: UUID(),
            deviceInfo: nil,
            deviceName: "Laptop",
            loginIp: "10.0.0.1",
            loginLocation: nil,
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            isCurrent: false
        )
        XCTAssertEqual(sessionIpOnly.displayLocationLine, "10.0.0.1")

        let sessionNeither = UserSession(
            id: UUID(),
            deviceInfo: nil,
            deviceName: nil,
            loginIp: nil,
            loginLocation: nil,
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            isCurrent: false
        )
        XCTAssertNil(sessionNeither.displayLocationLine)
        XCTAssertEqual(sessionNeither.displayDevice, "Unknown device")
        XCTAssertEqual(sessionNeither.displayTitle, "Unknown device")

        // OS Only hardware label
        let sessionOsOnly = UserSession(
            id: UUID(),
            deviceInfo: "iOS 18.0",
            deviceName: "iPhone",
            createdAt: now,
            expiresAt: now.addingTimeInterval(3600),
            isCurrent: false
        )
        XCTAssertEqual(sessionOsOnly.displayPlatform, "iOS 18.0")
        XCTAssertEqual(sessionOsOnly.displayTitle, "iPhone")
    }
}
