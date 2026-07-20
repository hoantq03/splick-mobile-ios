import SwiftUI
import DesignSystem
import Common
import Localization
import SplickDomain

struct TransferGroupOwnershipSheet: View {
    let groupId: UUID
    let members: [GroupMemberItem]
    let currentUserId: UUID?
    let transferOwnershipUseCase: TransferGroupOwnershipUseCaseProtocol
    let onTransferred: (SplickDomain.Group) -> Void

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMemberId: UUID?
    @State private var isTransferring = false
    @State private var errorMessage: String?

    private var eligibleMembers: [GroupMemberItem] {
        members.filter { member in
            member.status == "ACTIVE"
                && !member.isOwner
                && member.userId != currentUserId
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if eligibleMembers.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: languageService.text(.friendsTransferNoMembersTitle),
                        message: languageService.text(.friendsTransferNoMembersMessage)
                    )
                } else {
                    List(eligibleMembers) { member in
                        Button {
                            selectedMemberId = member.userId
                        } label: {
                            HStack {
                                AvatarView(
                                    imageURL: member.avatarURL,
                                    name: member.displayName,
                                    size: .medium
                                )
                                VStack(alignment: .leading) {
                                    Text(member.displayName)
                                        .font(SplickTheme.Typography.headline)
                                    Text("@\(member.username)")
                                        .font(SplickTheme.Typography.caption)
                                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                                }
                                Spacer()
                                if selectedMemberId == member.userId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(languageService.text(.friendsTransferTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.friendsTransferAction)) {
                        Task { await transfer() }
                    }
                    .disabled(selectedMemberId == nil || isTransferring)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .padding()
                }
            }
        }
    }

    private func transfer() async {
        guard let newOwnerId = selectedMemberId else { return }
        isTransferring = true
        errorMessage = nil
        defer { isTransferring = false }

        do {
            let group = try await transferOwnershipUseCase.execute(
                groupId: groupId,
                newOwnerId: newOwnerId
            )
            onTransferred(group)
            dismiss()
        } catch {
            errorMessage = languageService.localizedMessage(for: error)
        }
    }
}
