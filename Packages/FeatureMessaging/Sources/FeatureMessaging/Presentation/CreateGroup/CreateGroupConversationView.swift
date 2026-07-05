import SwiftUI
import DesignSystem
import Localization
import SplickDomain

public struct CreateGroupConversationView: View {
    @ObservedObject private var viewModel: CreateGroupViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    let friends: [UserSummary]
    let onCreated: (Conversation) -> Void

    public init(
        viewModel: CreateGroupViewModel,
        friends: [UserSummary],
        onCreated: @escaping (Conversation) -> Void
    ) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.friends = friends
        self.onCreated = onCreated
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(languageService.text(.messagingGroupNamePlaceholder), text: $viewModel.groupName)
                }

                Section(languageService.text(.messagingGroupMembersTitle)) {
                    if friends.isEmpty {
                        Text(languageService.text(.messagingGroupNoFriends))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    } else {
                        ForEach(friends, id: \.id) { friend in
                            Button {
                                viewModel.toggleFriend(friend.id)
                            } label: {
                                HStack {
                                    AvatarView(
                                        imageURL: friend.avatarURL,
                                        name: friend.displayName ?? friend.username,
                                        size: .small
                                    )
                                    Text(friend.displayName ?? friend.username)
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    Spacer()
                                    if viewModel.selectedFriendIds.contains(friend.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(SplickTheme.Colors.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(SplickTheme.Colors.error)
                    }
                }
            }
            .navigationTitle(languageService.text(.messagingCreateGroupTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.messagingNewConversation)) {
                        Task {
                            if let conversation = await viewModel.createGroup() {
                                onCreated(conversation)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
        }
    }
}
