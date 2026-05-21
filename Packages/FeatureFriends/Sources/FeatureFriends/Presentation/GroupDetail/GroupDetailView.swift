import SwiftUI
import DesignSystem
import SplickDomain

struct GroupDetailView: View {
    let group: SplickDomain.Group
    let onUserTap: (UserSummary) -> Void
    let fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol
    let generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol
    let fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol
    let inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol

    @State private var showGroupQR = false
    @State private var showInviteFriends = false
    @State private var displayedInviteCode: String

    init(
        group: SplickDomain.Group,
        onUserTap: @escaping (UserSummary) -> Void,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol,
        fetchMyFriendsUseCase: FetchMyFriendsUseCaseProtocol,
        inviteFriendsUseCase: InviteFriendsToGroupUseCaseProtocol
    ) {
        self.group = group
        self.onUserTap = onUserTap
        self.fetchInviteCodeUseCase = fetchInviteCodeUseCase
        self.generateInviteCodeUseCase = generateInviteCodeUseCase
        self.fetchMyFriendsUseCase = fetchMyFriendsUseCase
        self.inviteFriendsUseCase = inviteFriendsUseCase
        _displayedInviteCode = State(initialValue: group.inviteCode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                headerCard

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    Text("Thành viên (\(group.memberCount))")
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)

                    LazyVStack(spacing: SplickTheme.Spacing.xs) {
                        ForEach(group.members) { member in
                            Button {
                                onUserTap(member)
                            } label: {
                                memberRow(member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(SplickTheme.Spacing.md)
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                groupActionsMenu
            }
        }
        .sheet(isPresented: $showGroupQR) {
            GroupInviteQRSheet(
                groupName: group.name,
                groupId: group.id,
                fetchInviteCodeUseCase: fetchInviteCodeUseCase,
                generateInviteCodeUseCase: generateInviteCodeUseCase
            )
        }
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsToGroupSheet(
                groupId: group.id,
                fetchMyFriendsUseCase: fetchMyFriendsUseCase,
                inviteFriendsUseCase: inviteFriendsUseCase,
                onInvited: {}
            )
        }
        .task {
            await refreshInviteCodeLabel()
        }
    }

    private var groupActionsMenu: some View {
        Menu {
            Button {
                showGroupQR = true
            } label: {
                Label("Mã QR & mã nhóm", systemImage: "qrcode")
            }

            Button {
                showInviteFriends = true
            } label: {
                Label("Thêm thành viên", systemImage: "person.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .accessibilityLabel("Thao tác nhóm")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 52, height: 52)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    Text(group.name)
                        .font(SplickTheme.Typography.title)
                    Text("\(group.memberCount) thành viên")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }

            if let description = group.description, !description.isEmpty {
                Text(description)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            if !displayedInviteCode.isEmpty {
                HStack {
                    Text("Mã mời: \(displayedInviteCode)")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    Spacer()
                }
            }
        }
        .splickCard()
    }

    private func refreshInviteCodeLabel() async {
        guard displayedInviteCode.isEmpty else { return }
        if let code = try? await fetchInviteCodeUseCase.execute(groupId: group.id) {
            displayedInviteCode = code.code
        }
    }

    private func memberRow(_ user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(imageURL: user.avatarURL, name: user.displayName, size: .medium)

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(user.displayName)
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text("@\(user.username)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
    }
}
