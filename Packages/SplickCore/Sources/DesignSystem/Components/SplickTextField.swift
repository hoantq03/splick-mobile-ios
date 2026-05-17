import SwiftUI

public struct SplickTextField: View {
    private let placeholder: String
    @Binding private var text: String
    private let isSecure: Bool
    private let errorMessage: String?
    private let icon: String?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        isSecure: Bool = false,
        errorMessage: String? = nil,
        icon: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.errorMessage = errorMessage
        self.icon = icon
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .frame(width: 20)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
            .overlay {
                RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small)
                    .strokeBorder(
                        errorMessage != nil ? SplickTheme.Colors.error : Color.clear,
                        lineWidth: 1
                    )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
    }
}
