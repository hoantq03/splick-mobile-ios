import SwiftUI
import DesignSystem

/// Inbox row label while a peer is typing — prefix stays fixed; dots cycle `.` → `..` → `...`.
struct ConversationListTypingPreview: View {
    let textPrefix: String

    private static let stepDuration: TimeInterval = 0.45
    private static let dotsColumnWidth: CGFloat = 18

    var body: some View {
        HStack(spacing: 0) {
            Text(textPrefix)
            TimelineView(.periodic(from: .now, by: Self.stepDuration)) { context in
                let step = Int(context.date.timeIntervalSinceReferenceDate / Self.stepDuration) % 3
                Text(String(repeating: ".", count: step + 1))
                    .frame(width: Self.dotsColumnWidth, alignment: .leading)
            }
        }
        .lineLimit(1)
        .accessibilityLabel("\(textPrefix)...")
    }
}
