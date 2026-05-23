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
        generateGroupQrUseCase: GenerateGroupQrUseCaseProtocol,
        revokeGroupQrUseCase: RevokeGroupQrUseCaseProtocol
    ) {
        self.groupName = groupName
        _viewModel = StateObject(
            wrappedValue: GroupInviteQRViewModel(
                groupId: groupId,
                generateGroupQrUseCase: generateGroupQrUseCase,
                revokeGroupQrUseCase: revokeGroupQrUseCase
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                VStack(spacing: SplickTheme.Spacing.xxs) {
                    Text(groupName)
                        .font(SplickTheme.Typography.title)
                    Text("Mã QR nhóm (bảo mật)")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
                .padding(.top, SplickTheme.Spacing.lg)

                qrContent

                if let qr = viewModel.serverQR {
                    Text("Hết hạn: \(qr.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                Text("Bạn bè quét mã để tham gia nhóm. Mã do máy chủ cấp, có thể thu hồi và làm mới.")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplickTheme.Spacing.xl)

                if let payload = viewModel.qrPayload {
                    ShareLink(item: payload) {
                        Label("Chia sẻ mã QR", systemImage: "square.and.arrow.up")
                            .font(SplickTheme.Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(SplickTheme.Spacing.sm)
                            .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
                    }
                    .padding(.horizontal, SplickTheme.Spacing.xl)
                }

                SplickButton("Làm mới mã QR", style: .secondary, isDisabled: viewModel.state == .loading) {
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
            LoadingView(message: "Đang tạo mã QR...")
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
