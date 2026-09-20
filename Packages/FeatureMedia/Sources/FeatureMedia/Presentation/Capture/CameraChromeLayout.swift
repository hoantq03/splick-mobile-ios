import UIKit
import DesignSystem

/// Adaptive camera chrome so tools stay fully visible on compact phones.
struct CameraChromeMetrics: Equatable {
    var shutterDiameter: CGFloat
    var galleryDiameter: CGFloat
    var sideControlDiameter: CGFloat
    var toolIconSize: CGFloat
    var toolLabelSize: CGFloat
    var previewLift: CGFloat
    var previewInset: CGFloat
    var topPadding: CGFloat
    var bottomPadding: CGFloat
    var toolsToShutterSpacing: CGFloat
    var shutterRowHorizontalPadding: CGFloat
}

enum CameraChromeLayout {
    static let previewAspect: CGFloat = 8 / 9
    static let toolCount: CGFloat = 4
    /// Extra rise of tools + shutter above the tab-aligned bottom inset once open.
    /// Applied via `CameraOpenRevealGeometry.shutterRowLift`, not the base padding —
    /// so progress 0 sits on the tab camera circle for the water reveal.
    static let chromeBottomExtraLift: CGFloat = 18

    static func metrics(in size: CGSize, safeArea: UIEdgeInsets) -> CameraChromeMetrics {
        let compactWidth = size.width < 400
        let compactHeight = size.height < 720
        let shutter = SplickTabBarMetrics.cameraSize
        let toolIcon: CGFloat = compactWidth ? 36 : 44
        return CameraChromeMetrics(
            shutterDiameter: shutter,
            galleryDiameter: compactWidth ? 44 : 50,
            sideControlDiameter: 44,
            toolIconSize: toolIcon,
            toolLabelSize: compactWidth ? 9 : 10,
            previewLift: compactHeight ? 8 : 24,
            previewInset: 12,
            topPadding: max(safeArea.top, 8),
            bottomPadding: SplickTabBarMetrics.cameraRevealBottomInset,
            toolsToShutterSpacing: compactHeight ? 20 : 24,
            shutterRowHorizontalPadding: compactWidth ? 16 : 20
        )
    }

    /// Width available for the four capture tools when they sit full-bleed.
    static func toolsRowWidth(containerWidth: CGFloat, inset: CGFloat = 8) -> CGFloat {
        max(containerWidth - inset * 2, 0)
    }

    static func toolColumnWidth(containerWidth: CGFloat) -> CGFloat {
        toolsRowWidth(containerWidth: containerWidth) / toolCount
    }

    static func windowSafeAreaInsets() -> UIEdgeInsets {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window?.safeAreaInsets ?? .zero
    }
}
