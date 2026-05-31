import SwiftUI
import DesignSystem

public struct TabBarBadgeView: View {
    public let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        if count > 0 {
            Text(displayText)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, count > 9 ? 4 : 0)
                .frame(minWidth: 14, minHeight: 14)
                .background(Capsule().fill(SplickTheme.Colors.error))
        }
    }

    private var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }
}
