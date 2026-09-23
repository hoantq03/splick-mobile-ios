import SwiftUI
import DesignSystem
import Localization
import Common
import SplickDomain

struct FailedUploadCaptionEditor: View {
    @EnvironmentObject private var languageService: LanguageService
    let post: Post
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var caption: String

    init(post: Post, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.post = post
        self.onSave = onSave
        self.onCancel = onCancel
        _caption = State(initialValue: post.caption ?? "")
    }

    private var isOverLimit: Bool {
        PostCaption.exceedsLimit(caption)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                TextEditor(text: $caption)
                    .font(SplickTheme.Typography.body)
                    .frame(minHeight: 180)
                    .padding(SplickTheme.Spacing.sm)
                    .background(SplickTheme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                    .onChange(of: caption) { newValue in
                        caption = PostCaption.limited(newValue)
                    }
                Text("\(PostCaption.characterCount(caption))/\(PostCaption.maxLength)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(isOverLimit ? SplickTheme.Colors.error : SplickTheme.Colors.textSecondary)
                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle(languageService.text(.feedUploadEditPost))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonSave)) {
                        onSave(caption)
                    }
                    .disabled(isOverLimit)
                }
            }
        }
    }
}
