import SwiftUI
import DesignSystem

struct AttachmentPickerPanelHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(SplickTheme.Typography.captionBold)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
            Spacer(minLength: 0)
        }
    }
}
