import PhotosUI
import SwiftUI
import DesignSystem
import Localization

enum QRScannerMode {
    case addFriend
    case joinGroup
    /// Single scanner for friend QR and group invite QR.
    case unified
}

struct QRScannerMyQrContext {
    let username: String
    let displayName: String
    let avatarURL: URL?
    let generateMyQrUseCase: GenerateMyQrUseCaseProtocol
}

struct QRScannerSheet: View {
    let mode: QRScannerMode
    let onScan: (String) -> Void
    var myQrContext: QRScannerMyQrContext?

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var albumScanErrorMessage: String?
    @State private var showMyQRSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                cameraSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.top, SplickTheme.Spacing.sm)
                    .padding(.bottom, SplickTheme.Spacing.sm)

                bottomActions
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.friendsClose)) { dismiss() }
                }
            }
            .alert(
                languageService.text(.friendsScanQRFromAlbum),
                isPresented: Binding(
                    get: { albumScanErrorMessage != nil },
                    set: { if !$0 { albumScanErrorMessage = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) {
                    albumScanErrorMessage = nil
                }
            } message: {
                Text(albumScanErrorMessage ?? "")
            }
            .sheet(isPresented: $showMyQRSheet) {
                if let myQrContext {
                    MyQRSheet(
                        username: myQrContext.username,
                        displayName: myQrContext.displayName,
                        avatarURL: myQrContext.avatarURL,
                        generateMyQrUseCase: myQrContext.generateMyQrUseCase
                    )
                }
            }
            .onChange(of: selectedPhotoItem) { item in
                Task { await handleSelectedPhoto(item) }
            }
        }
    }

    @ViewBuilder
    private var cameraSection: some View {
        ZStack {
            Group {
                if let errorMessage {
                    cameraUnavailableView(message: errorMessage)
                } else {
                    QRCodeScannerView(
                        onCodeScanned: { code in
                            onScan(code)
                            dismiss()
                        },
                        onError: { message in
                            errorMessage = message
                        }
                    )
                }
            }

            if errorMessage == nil {
                viewfinderOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous))
    }

    private var viewfinderOverlay: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height) * 0.62
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .allowsHitTesting(false)
    }

    private var bottomActions: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            if (mode == .addFriend || mode == .unified), myQrContext != nil {
                QRScannerOptionRow(
                    icon: "qrcode",
                    title: languageService.text(.friendsMyQRPreviewTitle),
                    action: { showMyQRSheet = true }
                )
                .frame(maxWidth: .infinity)
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                QRScannerOptionRow(
                    icon: "photo.on.rectangle.angled",
                    title: languageService.text(.friendsScanQRFromAlbum)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .padding(.vertical, SplickTheme.Spacing.md)
        .background(SplickTheme.Colors.background)
    }

    private func cameraUnavailableView(message: String) -> some View {
        VStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            Text(message)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.lg)

            #if targetEnvironment(simulator)
            Text(languageService.text(.friendsScanSimulatorHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SplickTheme.Spacing.lg)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let code = QRCodeImageDecoder.decode(from: image) else {
            albumScanErrorMessage = languageService.text(.friendsScanQRFromAlbumFailed)
            return
        }

        onScan(code)
        dismiss()
    }

    private var navigationTitle: String {
        switch mode {
        case .addFriend: return languageService.text(.friendsScanQRAddFriend)
        case .joinGroup: return languageService.text(.friendsScanQRJoinGroup)
        case .unified: return languageService.text(.friendsScanQRUnified)
        }
    }
}
