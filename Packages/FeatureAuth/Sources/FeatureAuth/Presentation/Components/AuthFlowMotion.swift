import SwiftUI
import DesignSystem

enum AuthFlowMotion {
    static let horizontalSlide = Animation.spring(
        response: 0.58,
        dampingFraction: 0.9,
        blendDuration: 0.16
    )

    static let fieldReveal = Animation.spring(
        response: 0.52,
        dampingFraction: 0.72,
        blendDuration: 0.1
    )

    static let credentialsFieldTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
}
