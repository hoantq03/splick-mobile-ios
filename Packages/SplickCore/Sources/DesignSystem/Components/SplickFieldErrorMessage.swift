import SwiftUI

/// Inline field error that expands and collapses height instead of popping in.
public struct SplickFieldErrorMessage: View {
    private let message: String?
    private let alignment: TextAlignment

    private static let reveal = Animation.spring(
        response: 0.34,
        dampingFraction: 0.92,
        blendDuration: 0.08
    )

    public init(_ message: String?, alignment: TextAlignment = .leading) {
        self.message = message
        self.alignment = alignment
    }

    public var body: some View {
        Group {
            if let message, !message.isEmpty {
                Text(message)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
                    .multilineTextAlignment(alignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .transition(Self.transition)
            }
        }
        .animation(Self.reveal, value: message)
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    private static let transition: AnyTransition = .asymmetric(
        insertion: .opacity.combined(with: .offset(y: -8)),
        removal: .opacity.combined(with: .offset(y: -6))
    )
}
