import SwiftUI
import DesignSystem
import SplickDomain

public struct FriendUserProfileView: View {
    @StateObject private var viewModel: FriendUserProfileViewModel
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
                    Text("@\(viewModel.user.username)")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                relationshipActions
                    .padding(.horizontal, SplickTheme.Spacing.xl)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
            .alert("Profile", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { viewModel.alertMessage = nil }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .confirmationDialog(
                "Remove friend?",
                isPresented: $viewModel.showRemoveConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove friend", role: .destructive) {
                    Task {
                        await viewModel.removeFriend()
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Block this user?",
                isPresented: $viewModel.showBlockConfirm,
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) {
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

    @ViewBuilder
    private var relationshipActions: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            switch viewModel.mode {
            case .friend:
                SplickButton("Đặt biệt danh", style: .secondary) {
                    viewModel.showNicknameEditor = true
                }
                .disabled(viewModel.isProcessing)

                SplickButton("Xóa bạn", style: .secondary) {
                    viewModel.showRemoveConfirm = true
                }
                .disabled(viewModel.isProcessing)

                Button("Chặn người dùng") {
                    viewModel.showBlockConfirm = true
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.red)
                .disabled(viewModel.isProcessing)

            case .stranger:
                Button("Chặn người dùng") {
                    viewModel.showBlockConfirm = true
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.red)
                .disabled(viewModel.isProcessing)

            case .blocked:
                SplickButton("Bỏ chặn", style: .secondary) {
                    Task {
                        await viewModel.unblockUser()
                        dismiss()
                    }
                }
                .disabled(viewModel.isProcessing)
            }

            if viewModel.isProcessing {
                ProgressView()
            }
        }
    }

    private var nicknameEditorSheet: some View {
        NavigationStack {
            Form {
                TextField("Nickname (only you see this)", text: $viewModel.nicknameDraft)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Nickname")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.showNicknameEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await viewModel.saveNickname() }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
