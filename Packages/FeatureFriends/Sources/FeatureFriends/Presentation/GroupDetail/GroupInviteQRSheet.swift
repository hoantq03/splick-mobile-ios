import SwiftUI
import DesignSystem
import Common

struct GroupInviteQRSheet: View {
    let groupName: String
    @StateObject private var viewModel: GroupInviteQRViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        groupName: String,
        groupId: UUID,
        fetchInviteCodeUseCase: FetchGroupInviteCodeUseCaseProtocol,
        generateInviteCodeUseCase: GenerateGroupInviteCodeUseCaseProtocol
    ) {
        self.groupName = groupName
        _viewModel = StateObject(
            wrappedValue: GroupInviteQRViewModel(
                groupId: groupId,
                fetchInviteCodeUseCase: fetchInviteCodeUseCase,
                generateInviteCodeUseCase: generateInviteCodeUseCase
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                VStack(spacing: SplickTheme.Spacing.xxs) {
                    Text(groupName)
                        .font(SplickTheme.Typography.title)
                    Text("Mã mời nhóm")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .padding(.top, SplickTheme.Spacing.lg)

                qrContent

                if let code = viewModel.inviteCode {
                    Text(code)
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .textSelection(.enabled)
                }

                Text("Bạn bè quét mã QR hoặc nhập mã để tham gia nhóm trên Splick.")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplickTheme.Spacing.xl)

                if let payload = viewModel.qrPayload {
                    ShareLink(item: payload) {
                        Label("Chia sẻ mã", systemImage: "square.and.arrow.up")
                            .font(SplickTheme.Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(SplickTheme.Spacing.sm)
                            .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
                    }
                    .padding(.horizontal, SplickTheme.Spacing.xl)
                }

                SplickButton("Làm mới mã", style: .secondary, isDisabled: viewModel.state == .loading) {
                    Task { await viewModel.refresh() }
                }
                .padding(.horizontal, SplickTheme.Spacing.xl)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationTitle("Mã QR nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .alert("Lỗi", isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var qrContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Đang tải mã QR...")
                .frame(height: 260)
        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.load() }
            }
            .frame(height: 260)
        case .loaded:
            if let payload = viewModel.qrPayload,
               let qrImage = QRCodeGenerator.image(from: payload, dimension: 220) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(SplickTheme.Spacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
            } else {
                Text("Không thể tạo mã QR")
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }
}
