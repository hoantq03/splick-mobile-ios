import SwiftUI
import Photos
import UIKit
import DesignSystem
import Common

struct GroupInviteQRSheet: View {
    let groupName: String
    @StateObject private var viewModel: GroupInviteQRViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showShareSheet = false
    @State private var isSavingImage = false
    @State private var feedbackMessage: String?

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

                if qrExportImage != nil {
                    actionButtons
                        .padding(.horizontal, SplickTheme.Spacing.md)
                }

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
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems {
                    GroupQRShareSheet(items: items)
                }
            }
            .alert("", isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { if !$0 { feedbackMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackMessage ?? "")
            }
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

    private var actionButtons: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            qrActionButton(
                icon: "square.and.arrow.down",
                title: "Lưu ảnh",
                isLoading: isSavingImage
            ) {
                Task { await saveQRImage() }
            }
            .disabled(isSavingImage || viewModel.isRefreshing)

            qrActionButton(
                icon: "arrow.clockwise",
                title: "Làm mới",
                isLoading: viewModel.isRefreshing
            ) {
                Task { await viewModel.refresh() }
            }
            .disabled(viewModel.isRefreshing || isSavingImage)

            qrActionButton(icon: "square.and.arrow.up", title: "Chia sẻ") {
                showShareSheet = true
            }
            .disabled(shareItems == nil || viewModel.isRefreshing || isSavingImage)
        }
    }

    private func qrActionButton(
        icon: String,
        title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                        Text(title)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .padding(.horizontal, SplickTheme.Spacing.xs)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
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
            if let image = qrDisplayImage {
                ZStack {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)

                    if viewModel.isRefreshing {
                        Color.white.opacity(0.75)
                        ProgressView()
                    }
                }
                .padding(SplickTheme.Spacing.md)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                .frame(height: 260)
            } else {
                Text("Không thể tạo mã QR")
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private var qrDisplayImage: UIImage? {
        guard let payload = viewModel.qrPayload else { return nil }
        return QRCodeGenerator.image(from: payload, dimension: 220)
    }

    private var qrExportImage: UIImage? {
        guard let payload = viewModel.qrPayload else { return nil }
        return QRCodeGenerator.image(from: payload, dimension: 1024)
    }

    private var shareItems: [Any]? {
        guard let qrExportImage else { return nil }
        var items: [Any] = [qrExportImage]
        if let shareURL = viewModel.shareURL {
            items.append(shareURL)
        }
        return items
    }

    private func saveQRImage() async {
        guard let qrExportImage else {
            feedbackMessage = "Không thể lưu ảnh mã QR."
            return
        }

        isSavingImage = true
        defer { isSavingImage = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            feedbackMessage = "Không có quyền lưu ảnh vào thư viện."
            return
        }

        let saved = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: qrExportImage)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }

        feedbackMessage = saved ? "Đã lưu mã QR vào thư viện ảnh." : "Không thể lưu ảnh mã QR."
    }
}

private struct GroupQRShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
