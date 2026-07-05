import SwiftUI
import Common
import DesignSystem
import Localization
import SplickDomain

public struct FriendUserProfileView: View {
    @StateObject private var viewModel: FriendUserProfileViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openDirectMessage) private var openDirectMessage

    public init(viewModel: FriendUserProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.lg) {
                    AvatarView(
                        imageURL: viewModel.user.avatarURL,
                        name: viewModel.user.displayName,
                        size: .large,
                        userId: viewModel.user.id
                    )
                    .padding(.top, SplickTheme.Spacing.xl)

                    VStack(spacing: SplickTheme.Spacing.xxs) {
                        Text(viewModel.user.displayName)
                            .font(SplickTheme.Typography.largeTitle)
                        if viewModel.isBotProfile {
                            Text(languageService.text(.splickBotProfileTagline))
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        } else if let subtitle = viewModel.user.subtitle {
                            Text(subtitle)
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                        Text("@\(viewModel.user.username)")
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }

                    if viewModel.isBotProfile {
                        botProfileContent
                            .padding(.horizontal, SplickTheme.Spacing.xl)
                    } else if let stats = viewModel.stats {
                        statsRow(stats)
                            .padding(.top, SplickTheme.Spacing.md)
                    }

                    if !viewModel.isBotProfile, let profileError = viewModel.profileError {
                        Text(profileError)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SplickTheme.Spacing.xl)

                        SplickButton(languageService.text(.profileRetry), style: .secondary) {
                            Task { await viewModel.loadProfile() }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.xl)
                    } else if !viewModel.isBotProfile {
                        relationshipActions
                            .padding(.horizontal, SplickTheme.Spacing.md)
                    }
                }
                .padding(.bottom, SplickTheme.Spacing.xxl)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .overlay {
                if !viewModel.isBotProfile,
                   viewModel.isLoadingProfile && viewModel.stats == nil {
                    LoadingView(message: languageService.text(.profileLoading))
                }
            }
            .task {
                await viewModel.loadProfile()
            }
            .alert("Profile", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button(languageService.text(.commonOK), role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .confirmationDialog(
                languageService.text(.friendsRemoveFriendConfirmTitle),
                isPresented: $viewModel.showRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button(languageService.text(.friendsRemoveFriendConfirmAction), role: .destructive) {
                    Task {
                        await viewModel.removeFriend()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                languageService.text(.friendsBlockConfirmTitle),
                isPresented: $viewModel.showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button(languageService.text(.friendsBlockConfirmAction), role: .destructive) {
                    Task {
                        await viewModel.blockUser()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showNicknameEditor) {
                nicknameEditorSheet
            }
            .sheet(isPresented: $viewModel.showPaymentSheet) {
                FriendPaymentProfileSheet(
                    user: viewModel.user,
                    paymentProfile: viewModel.paymentProfile,
                    isLoading: viewModel.isLoadingFriendPayment,
                    notConfigured: viewModel.friendPaymentNotConfigured,
                    errorMessage: viewModel.paymentProfileError
                )
            }
        }
    }

    private func statsRow(_ stats: UserProfileStats) -> some View {
        HStack(spacing: SplickTheme.Spacing.xl) {
            statBlock(value: stats.friendCount, label: languageService.text(.profileStatFriends))
            statBlock(value: stats.postCount, label: languageService.text(.profileStatPosts))
            statBlock(value: stats.groupCount, label: languageService.text(.profileStatGroups))
        }
    }

    private func statBlock(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(SplickTheme.Typography.title)
            Text(label)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(SplickTheme.Typography.title)
            Text(label)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
    }

    private var botProfileContent: some View {
        VStack(spacing: SplickTheme.Spacing.lg) {
            HStack(spacing: SplickTheme.Spacing.xl) {
                statBlock(
                    value: "\(SplickBot.remindersSentCount.formatted())+",
                    label: languageService.text(.splickBotStatReminders)
                )
                statBlock(
                    value: languageService.text(.splickBotStatRecoveryValue),
                    label: languageService.text(.splickBotStatRecovery)
                )
                statBlock(
                    value: languageService.text(.splickBotStatExperienceValue),
                    label: languageService.text(.splickBotStatExperience)
                )
            }
            .padding(.top, SplickTheme.Spacing.md)

            Text(languageService.text(.splickBotProfileBio))
                .font(SplickTheme.Typography.body)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(SplickTheme.Spacing.md)
                .background(SplickTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
        }
    }

    @ViewBuilder
    private var relationshipActions: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            switch viewModel.mode {
            case .friend:
                friendActionGrid

            case .stranger:
                switch viewModel.friendStatus {
                case .none:
                    SplickButton(languageService.text(.feedProfileAddFriend)) {
                        Task { await viewModel.addFriend() }
                    }
                    .disabled(viewModel.isProcessing)
                case .requestReceived:
                    SplickButton(languageService.text(.friendsAccept)) {
                        Task { await viewModel.acceptFriendRequest() }
                    }
                    .disabled(viewModel.isProcessing)
                case .requestSent:
                    SplickButton(languageService.text(.friendsRecallRequest), style: .destructive) {
                        Task { await viewModel.cancelFriendRequest() }
                    }
                    .disabled(viewModel.isProcessing)
                default:
                    EmptyView()
                }

                Button(languageService.text(.friendsBlockUser)) {
                    viewModel.showBlockConfirm = true
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.red)
                .disabled(viewModel.isProcessing)

            case .blocked:
                SplickButton(languageService.text(.friendsUnblock), style: .secondary) {
                    Task {
                        await viewModel.unblockUser()
                        dismiss()
                    }
                }
                .disabled(viewModel.isProcessing)
            }

            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.regular)
            }
        }
    }

    private var friendActionGrid: some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                if let openDM = openDirectMessage {
                    ProfileCompactActionButton(
                        icon: "message.fill",
                        title: languageService.text(.messagingMessageButton),
                        tint: SplickTheme.Colors.primaryGradientStart,
                        isDisabled: viewModel.isProcessing
                    ) {
                        Task { _ = await openDM(viewModel.user.id) }
                    }
                }

                ProfileCompactActionButton(
                    icon: "person.text.rectangle",
                    title: languageService.text(.friendsSetNickname),
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showNicknameEditor = true
                }

                ProfileCompactActionButton(
                    icon: "qrcode",
                    title: languageService.text(.profilePaymentManage),
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showPaymentSheet = true
                }
            }

            HStack(spacing: SplickTheme.Spacing.xs) {
                ProfileCompactActionButton(
                    icon: "person.badge.minus",
                    title: languageService.text(.friendsRemoveFriend),
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showRemoveConfirm = true
                }

                ProfileCompactActionButton(
                    icon: "hand.raised.fill",
                    title: languageService.text(.friendsBlockUser),
                    tint: SplickTheme.Colors.error,
                    isDisabled: viewModel.isProcessing
                ) {
                    viewModel.showBlockConfirm = true
                }

                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var nicknameEditorSheet: some View {
        NavigationStack {
            Form {
                TextField(languageService.text(.friendsNicknamePlaceholder), text: $viewModel.nicknameDraft)
                    .autocorrectionDisabled()
            }
            .navigationTitle(languageService.text(.friendsNicknameTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { viewModel.showNicknameEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonSave)) {
                        Task { await viewModel.saveNickname() }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
