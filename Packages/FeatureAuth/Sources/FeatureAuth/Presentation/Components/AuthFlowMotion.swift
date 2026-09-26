import SwiftUI
import DesignSystem

enum AuthFlowMotion {
    static let horizontalSlide = Animation.spring(
        response: 0.58,
        dampingFraction: 0.9,
        blendDuration: 0.16
    )

    static let fieldReveal = Animation.spring(
        response: 0.42,
        dampingFraction: 0.9,
        blendDuration: 0.12
    )

    static let countryCodeReveal = Animation.spring(
        response: 0.38,
        dampingFraction: 0.9,
        blendDuration: 0.1
    )

    static let credentialsFieldTransition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .offset(y: -10)),
        removal: .opacity.combined(with: .offset(y: -8))
    )

    static let countryCodeTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .leading).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
}
