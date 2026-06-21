import SwiftUI
import DesignSystem

enum AuthFlowMotion {
    static let horizontalSlide = Animation.spring(
        response: 0.58,
        dampingFraction: 0.9,
        blendDuration: 0.16
    )
}
