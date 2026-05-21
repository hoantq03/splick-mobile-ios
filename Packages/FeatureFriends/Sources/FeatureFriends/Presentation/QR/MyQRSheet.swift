import SwiftUI
import DesignSystem
import Common

struct MyQRSheet: View {
    let username: String
    let displayName: String
    let avatarURL: URL?

    @StateObject private var viewModel: MyQRViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        username: String,
        displayName: String,
        avatarURL: URL?,
        generateMyQrUseCase: GenerateMyQrUseCaseProtocol
    ) {
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        _viewModel = StateObject(wrappedValue: MyQRViewModel(generateMyQrUseCase: generateMyQrUseCase))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: SplickTheme.Spacing.lg) {
                AvatarView(imageURL: avatarURL, name: displayName, size: .large)
                    .padding(.top, SplickTheme.Spacing.lg)

                VStack(spacing: SplickTheme.Spacing.xxs) {
                    Text(displayName)
                        .font(SplickTheme.Typography.title)
                    Text("@\(username)")
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                    if let version = viewModel.version {
                        Text("Phiên bản mã \(version)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }

                qrContent

                Text("Bạn bè quét mã này để gửi lời mời kết bạn trên Splick.")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplickTheme.Spacing.xl)

                if let payload = viewModel.payload {
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
            .navigationTitle("Mã QR của tôi")
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
            if let payload = viewModel.payload, let qrImage = QRCodeGenerator.image(from: payload, dimension: 220) {
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
