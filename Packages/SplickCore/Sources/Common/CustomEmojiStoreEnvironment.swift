import SwiftUI

private struct CustomEmojiStoreKey: EnvironmentKey {
  static let defaultValue = CustomEmojiStore()
}

extension EnvironmentValues {
  public var customEmojiStore: CustomEmojiStore {
    get { self[CustomEmojiStoreKey.self] }
    set { self[CustomEmojiStoreKey.self] = newValue }
  }
}
