import SwiftUI
import DesignSystem

struct AuthMethodPicker<Method: Hashable & Identifiable>: View where Method: Sendable {
    @Binding var selection: Method
    let methods: [Method]
    let title: (Method) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(methods) { method in
                Button {
                    selection = method
                } label: {
                    Text(title(method))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(selection == method ? .semibold : .regular)
                        .foregroundStyle(
                            selection == method
                                ? SplickTheme.Colors.textPrimary
                                : SplickTheme.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(SplickTheme.Spacing.xxs)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
    }
}
