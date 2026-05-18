import SwiftUI
import DesignSystem

/// Opens the system emoji keyboard via a focused text field.
struct EmojiPickerSheet: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                Text("Chọn emoji")
                    .font(SplickTheme.Typography.title)

                TextField("Tap to open emoji keyboard", text: $draft)
                    .font(.system(size: 48))
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .onChange(of: draft) { newValue in
                        guard let emoji = Self.extractLastEmoji(from: newValue) else { return }
                        onPick(emoji)
                        dismiss()
                    }

                Text("Bàn phím emoji của iPhone sẽ hiện khi bạn chạm vào ô trên.")
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }
        }
        .presentationDetents([.medium])
    }

    private static func extractLastEmoji(from text: String) -> String? {
        for character in text.reversed() {
            if character.isEmoji {
                return String(character)
            }
        }
        return nil
    }
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji }
    }
}
