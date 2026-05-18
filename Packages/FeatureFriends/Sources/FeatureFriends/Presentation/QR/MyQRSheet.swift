import SwiftUI
import DesignSystem

struct MyQRSheet: View {
    let username: String
    let displayName: String
    let avatarURL: URL?

    @Environment(\.dismiss) private var dismiss

    private var payload: String {
        SplickQRParser.friendPayload(username: username)
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
                }

                if let qrImage = QRCodeGenerator.image(from: payload, dimension: 220) {
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

                Text("Bạn bè quét mã này để thêm bạn trên Splick.")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplickTheme.Spacing.xl)

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
        }
    }
}
