import SwiftUI
import Photos
import UIKit
import DesignSystem
import Common
import Localization

struct MyQRSheet: View {
    let username: String
    let displayName: String
    let avatarURL: URL?

    @StateObject private var viewModel: MyQRViewModel
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var isSavingImage = false
    @State private var feedbackMessage: String?

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
            ScrollView {
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
                            Text(languageService.format(.friendsMyQRVersion, version))
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }
                    }

                    qrContent

                    Text(languageService.text(.friendsMyQRHint))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, SplickTheme.Spacing.xl)

                    if qrUIImage != nil {
                        actionButtons
                            .padding(.horizontal, SplickTheme.Spacing.md)
                    }
                }
                .padding(.bottom, SplickTheme.Spacing.xxl)
            }
            .frame(maxWidth: .infinity)
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.friendsMyQRTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .task { await viewModel.load() }
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems {
                    MyQRShareSheet(items: items)
                }
            }
            .alert("", isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { if !$0 { feedbackMessage = nil } }
            )) {
                Button(languageService.text(.commonOK), role: .cancel) {}
            } message: {
                Text(feedbackMessage ?? "")
            }
            .alert(languageService.text(.commonError), isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )) {
                Button(languageService.text(.commonOK), role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Button {
                showShareSheet = true
            } label: {
                Label(languageService.text(.profilePaymentShare), systemImage: "square.and.arrow.up")
                    .font(SplickTheme.Typography.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                Task { await saveQRImage() }
            } label: {
                Group {
                    if isSavingImage {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(languageService.text(.profilePaymentSaveImage), systemImage: "square.and.arrow.down")
                    }
                }
                .font(SplickTheme.Typography.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSavingImage)
        }
    }

    @ViewBuilder
    private var qrContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: languageService.text(.friendsMyQRGenerating))
                .frame(height: 260)
        case .failed(let message):
            ErrorView(message: message) {
                Task { await viewModel.load() }
            }
            .frame(height: 260)
        case .loaded:
            if let image = qrUIImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .padding(SplickTheme.Spacing.md)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
            } else {
                Text(languageService.text(.friendsMyQRFailed))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
    }

    private var qrUIImage: UIImage? {
        guard let payload = viewModel.payload else { return nil }
        return QRCodeGenerator.image(from: payload, dimension: 1024)
    }

    private var shareItems: [Any]? {
        guard let qrUIImage else { return nil }
        return [
            qrUIImage,
            AppConstants.Links.profileInviteURL(username: username)
        ]
    }

    private func saveQRImage() async {
        guard let qrUIImage else {
            feedbackMessage = languageService.text(.profilePaymentImageSaveFailed)
            return
        }

        isSavingImage = true
        defer { isSavingImage = false }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            feedbackMessage = languageService.text(.profilePaymentImageSaveFailed)
            return
        }

        let saved = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: qrUIImage)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }

        feedbackMessage = saved
            ? languageService.text(.profilePaymentImageSaved)
            : languageService.text(.profilePaymentImageSaveFailed)
    }
}

private struct MyQRShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
