import Foundation
import Testing
@testable import Localization

struct PresenceDisplayPolicyTests {
    @Test
    func hidesLastSeenWhenOnline() {
        let text = PresenceDisplayPolicy.lastSeenText(
            isOnline: true,
            lastSeenAt: Date().addingTimeInterval(-300),
            appLocale: .en
        )
        #expect(text == nil)
    }

    @Test
    func hidesLastSeenAfterTwentyFourHours() {
        let text = PresenceDisplayPolicy.lastSeenText(
            isOnline: false,
            lastSeenAt: Date().addingTimeInterval(-(25 * 60 * 60)),
            appLocale: .en
        )
        #expect(text == nil)
    }

    @Test
    func showsLastSeenWithinTwentyFourHoursEnglish() {
        let text = PresenceDisplayPolicy.lastSeenText(
            isOnline: false,
            lastSeenAt: Date().addingTimeInterval(-(2 * 60 * 60)),
            appLocale: .en,
            now: Date()
        )
        #expect(text != nil)
    }

    @Test
    func showsLastSeenWithinTwentyFourHoursVietnamese() {
        let text = PresenceDisplayPolicy.lastSeenText(
            isOnline: false,
            lastSeenAt: Date().addingTimeInterval(-(45 * 60)),
            appLocale: .vi,
            now: Date()
        )
        #expect(text != nil)
    }
}
