import SwiftUI
import DesignSystem
import SplickDomain

struct CompanionsSheetRoute: Identifiable {
    let id: UUID
    let companions: [UserSummary]
}

struct CompanionsListSheet: View {
    let companions: [UserSummary]
    let onUserTap: (UserSummary) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if companions.isEmpty {
                    VStack(spacing: SplickTheme.Spacing.sm) {
                        Image(systemName: "person.2.slash")
                            .font(.largeTitle)
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                        Text("Không tìm thấy người đi cùng")
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(companions) { friend in
                        Button {
                            dismiss()
                            onUserTap(friend)
                        } label: {
                            HStack(spacing: SplickTheme.Spacing.sm) {
                                AvatarView(
                                    imageURL: friend.avatarURL,
                                    name: friend.displayName,
                                    size: .small
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(SplickTheme.Typography.headline)
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    Text("@\(friend.username)")
                                        .font(SplickTheme.Typography.caption)
                                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                                }
                            }
                            .padding(.vertical, SplickTheme.Spacing.xxs)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Đang ở cùng (\(companions.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
