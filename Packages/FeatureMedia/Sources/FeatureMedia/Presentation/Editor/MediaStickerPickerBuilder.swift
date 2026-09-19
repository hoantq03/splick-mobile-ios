import Foundation
import SwiftUI

public typealias MediaStickerPickerBuilder = (
    _ onDismiss: @escaping () -> Void,
    _ onSelectGifURL: @escaping (URL) -> Void,
    _ onSelectEmoji: @escaping (String) -> Void
) -> AnyView
