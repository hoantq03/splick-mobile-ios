import SwiftUI
import UIKit
import Common

/// Transparent UIKit button overlay that invokes `action` **without** resigning
/// the current first responder. SwiftUI `Button` / `onTapGesture` bounce the
/// keyboard on every Send; UIButton does not.
public struct KeyboardStickyTapControl<Label: View>: View {
    public var isEnabled: Bool
    public var action: () -> Void
    @ViewBuilder public var label: () -> Label

    public init(
        isEnabled: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.isEnabled = isEnabled
        self.action = action
        self.label = label
    }

    public var body: some View {
        label()
            .opacity(isEnabled ? 1 : 0.4)
            .overlay {
                KeyboardStickyUIButton(isEnabled: isEnabled, action: action)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
    }
}

private struct KeyboardStickyUIButton: UIViewRepresentable {
    var isEnabled: Bool
    var action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.accessibilityIdentifier = KeyboardDismissExempt.accessibilityIdentifier
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        uiView.isEnabled = isEnabled
        context.coordinator.action = action
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIButton, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func tapped() {
            action()
        }
    }
}
