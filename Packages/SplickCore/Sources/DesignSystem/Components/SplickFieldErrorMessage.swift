import SwiftUI

/// Inline field error that expands and collapses height instead of popping in.
public struct SplickFieldErrorMessage: View {
    private let message: String?
    private let alignment: TextAlignment

    private static let reveal = Animation.timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.42)

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
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
}
