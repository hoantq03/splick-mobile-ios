import SwiftUI
import FeatureStickers

public struct MessagingGifPickerFactoryKey: EnvironmentKey {
    public static let defaultValue: (() -> GifPickerViewModel)? = nil
}

public extension EnvironmentValues {
    var messagingGifPickerFactory: (() -> GifPickerViewModel)? {
        get { self[MessagingGifPickerFactoryKey.self] }
        set { self[MessagingGifPickerFactoryKey.self] = newValue }
    }
}
