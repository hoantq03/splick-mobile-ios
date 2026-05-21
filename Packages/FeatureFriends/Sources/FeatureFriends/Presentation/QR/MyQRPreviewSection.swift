import SwiftUI
import DesignSystem
import Common

/// Compact “my QR” block for the scan screen (below camera).
struct MyQRPreviewSection: View {
    let username: String
    let displayName: String
    let avatarURL: URL?

    private let generateMyQrUseCase: GenerateMyQrUseCaseProtocol

    @StateObject private var viewModel: MyQRViewModel
    @State private var showFullSheet = false

    init(
        username: String,
        displayName: String,
        avatarURL: URL?,
        generateMyQrUseCase: GenerateMyQrUseCaseProtocol
    ) {
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.generateMyQrUseCase = generateMyQrUseCase
        _viewModel = StateObject(wrappedValue: MyQRViewModel(generateMyQrUseCase: generateMyQrUseCase))
    }

    var body: some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Text("Mã QR của tôi")
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showFullSheet = true
            } label: {
                HStack(spacing: SplickTheme.Spacing.md) {
                    previewImage
                        .frame(width: 88, height: 88)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
                        Text(displayName)
                            .font(SplickTheme.Typography.headline)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                        Text("@\(username)")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        Text("Chạm để phóng to hoặc chia sẻ")
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }

                    Spacer(minLength: 0)
                }
                .padding(SplickTheme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $showFullSheet) {
            MyQRSheet(
                username: username,
                displayName: displayName,
                avatarURL: avatarURL,
                generateMyQrUseCase: generateMyQrUseCase
            )
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
        case .failed:
            Image(systemName: "qrcode")
                .font(.system(size: 32))
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        case .loaded:
            if let payload = viewModel.payload,
               let image = QRCodeGenerator.image(from: payload, dimension: 88) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 32))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }
}
