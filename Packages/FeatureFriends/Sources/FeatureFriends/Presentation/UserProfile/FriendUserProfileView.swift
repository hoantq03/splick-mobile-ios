import SwiftUI
import DesignSystem
import Localization
import SplickDomain

public struct FriendUserProfileView: View {
    @StateObject private var viewModel: FriendUserProfileViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: FriendUserProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                AvatarView(
                    imageURL: viewModel.user.avatarURL,
                    name: viewModel.user.displayName,
                    size: .large
                )
                .padding(.top, SplickTheme.Spacing.xl)

                VStack(spacing: SplickTheme.Spacing.xxs) {
                    Text(viewModel.user.displayName)
                        .font(SplickTheme.Typography.largeTitle)
                    if let subtitle = viewModel.user.subtitle {
                        Text(subtitle)
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                    Text("@\(viewModel.user.username)")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                if let stats = viewModel.stats {
                    statsRow(stats)
                        .padding(.top, SplickTheme.Spacing.md)
                }

                if let profileError = viewModel.profileError {
                    Text(profileError)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.xl)

                    SplickButton(languageService.text(.profileRetry), style: .secondary) {
                        Task { await viewModel.loadProfile() }
                    }
                    .padding(.horizontal, SplickTheme.Spacing.xl)
                } else {
                    relationshipActions
                        .padding(.horizontal, SplickTheme.Spacing.xl)

                    if let paymentProfile = viewModel.paymentProfile {
                        friendPaymentSection(paymentProfile)
                            .padding(.horizontal, SplickTheme.Spacing.xl)
                    }
                }

                Spacer()
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
                if viewModel.isLoadingProfile && viewModel.stats == nil {
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

    @ViewBuilder
    private var relationshipActions: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            switch viewModel.mode {
            case .friend:
                SplickButton(languageService.text(.friendsSetNickname), style: .secondary) {
                    viewModel.showNicknameEditor = true
                }
                .disabled(viewModel.isProcessing)

                SplickButton(languageService.text(.friendsRemoveFriend), style: .secondary) {
                    viewModel.showRemoveConfirm = true
                }
                .disabled(viewModel.isProcessing)

                Button(languageService.text(.friendsBlockUser)) {
                    viewModel.showBlockConfirm = true
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.red)
                .disabled(viewModel.isProcessing)

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
                    Text(languageService.text(.friendsRelationSent))
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                default:
                    EmptyView()
                }

                if viewModel.friendStatus != .requestSent {
                    Button(languageService.text(.friendsBlockUser)) {
                        viewModel.showBlockConfirm = true
                    }
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.red)
                    .disabled(viewModel.isProcessing)
                }

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
                SplickSpinner(size: .medium)
            }
        }
    }

    private func friendPaymentSection(_ profile: PaymentProfile) -> some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.profilePaymentFriendSection))
                .font(SplickTheme.Typography.headline)

            if let url = profile.qrImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .frame(maxWidth: .infinity)
                    default:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            if profile.hasBankDetails {
                VStack(alignment: .leading, spacing: 4) {
                    if let accountName = profile.accountName {
                        Text(accountName)
                            .font(SplickTheme.Typography.body)
                    }
                    if let accountNumber = profile.accountNumber {
                        Text(accountNumber)
                            .font(SplickTheme.Typography.callout.monospaced())
                    }
                    if let bankName = profile.bankName {
                        Text(bankName)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SplickTheme.Spacing.md)
        .background(SplickTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
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
