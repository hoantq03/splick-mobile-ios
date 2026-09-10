import CoreGraphics
import SwiftUI

/// iOS medium-widget proportions (~2.04:1) sized for photo overlays.
enum EditorWidgetLayout {
    static let size = CGSize(width: 170, height: 84)
    static let cornerRadius: CGFloat = 18
    static let contentInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)

    static var backgroundColor: Color {
        Color(red: 0.19, green: 0.21, blue: 0.25)
    }
}

struct WidgetStickerShell<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: EditorWidgetLayout.cornerRadius, style: .continuous)
                .fill(EditorWidgetLayout.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: EditorWidgetLayout.cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8)
                )

            content()
                .padding(EditorWidgetLayout.contentInsets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: EditorWidgetLayout.size.width, height: EditorWidgetLayout.size.height)
        .clipShape(RoundedRectangle(cornerRadius: EditorWidgetLayout.cornerRadius, style: .continuous))
    }
}
