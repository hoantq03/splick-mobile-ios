import CoreGraphics
import PencilKit
import SwiftUI

struct ImageAdjustments: Equatable {
    var brightness: Float = 0
    var contrast: Float = 1
    var saturation: Float = 1
    var exposure: Float = 0

    static let identity = ImageAdjustments()

    var isIdentity: Bool {
        abs(brightness) < 0.001
            && abs(contrast - 1) < 0.001
            && abs(saturation - 1) < 0.001
            && abs(exposure) < 0.001
    }
}

/// Non-destructive editor parameters. Undo stores these values — never pixel buffers.
struct EditState: Equatable {
    var cropRect: CGRect
    var rotationQuarters: Int
    var drawing: PKDrawing
    var textItems: [EditorTextItem]
    var stickerItems: [EditorStickerItem]
    var gifStickerData: [UUID: Data]
    var activeFilter: FilterPreset
    var adjustments: ImageAdjustments

    static let fullImageCropRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    static func initial(filter: FilterPreset) -> EditState {
        EditState(
            cropRect: fullImageCropRect,
            rotationQuarters: 0,
            drawing: PKDrawing(),
            textItems: [],
            stickerItems: [],
            gifStickerData: [:],
            activeFilter: filter,
            adjustments: .identity
        )
    }

    var normalizedRotation: Int {
        let raw = rotationQuarters % 4
        return raw < 0 ? raw + 4 : raw
    }

    var isEffectiveCrop: Bool {
        cropRect.minX > 0.001
            || cropRect.minY > 0.001
            || cropRect.width < 0.999
            || cropRect.height < 0.999
    }
}
