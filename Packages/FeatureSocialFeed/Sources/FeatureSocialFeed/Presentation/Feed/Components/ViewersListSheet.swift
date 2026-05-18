import SwiftUI
import DesignSystem
import SplickDomain

struct ViewersListSheet: View {
    let viewers: [UserSummary]
    let onUserTap: (UserSummary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewers) { viewer in
                Button {
                    dismiss()
                    onUserTap(viewer)
                } label: {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        AvatarView(
                            imageURL: viewer.avatarURL,
                            name: viewer.displayName,
                            size: .small
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewer.displayName)
                                .font(SplickTheme.Typography.headline)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Text("@\(viewer.username)")
                                .font(.system(size: 11))
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Đã xem (\(viewers.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }
}
