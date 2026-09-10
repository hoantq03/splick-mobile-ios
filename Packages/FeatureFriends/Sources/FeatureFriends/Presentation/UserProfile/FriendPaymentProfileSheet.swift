import SwiftUI
import Photos
import UIKit
import DesignSystem
import Localization
import SplickDomain

struct FriendPaymentProfileSheet: View {
    let user: UserSummary
    let paymentProfile: PaymentProfile?
    let isLoading: Bool
    let notConfigured: Bool
    let errorMessage: String?

    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss

    @State private var qrImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isSavingImage = false
    @State private var showShareSheet = false
    @State private var feedbackMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SplickTheme.Spacing.md) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.regular)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, SplickTheme.Spacing.xxl)
                    } else if let errorMessage {
                        paymentMessageCard(errorMessage, isError: true)
                    } else if notConfigured {
                        paymentMessageCard(
                            languageService.text(.profilePaymentEmptyFriend),
                            isError: false
                        )
                    } else if let paymentProfile {
                        PaymentProfileSummaryView(
                            profile: paymentProfile,
                            title: languageService.text(.profilePaymentFriendSection)
                        )

                        if paymentProfile.hasQrImage || paymentProfile.hasDisplayableBankFields {
                            actionButtons(for: paymentProfile)
                        }
                    }
                }
                .padding(SplickTheme.Spacing.md)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.profilePaymentFriendSection))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .task(id: paymentProfile?.qrImageURL) {
                await loadQRImageIfNeeded()
            }
            .sheet(isPresented: $showShareSheet) {
                if let items = shareItems {
                    PaymentProfileShareSheet(items: items)
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
        }
    }

    @ViewBuilder
    private func actionButtons(for profile: PaymentProfile) -> some View {
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

            if profile.hasQrImage {
                Button {
                    Task { await saveQRImage() }
                } label: {
                    Group {
                        if isSavingImage {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(
                                languageService.text(.profilePaymentSaveImage),
                                systemImage: "square.and.arrow.down"
                            )
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
                .disabled(isSavingImage || isLoadingImage)
            }
        }
    }

    private func paymentMessageCard(_ message: String, isError: Bool) -> some View {
        Text(message)
            .font(SplickTheme.Typography.callout)
            .foregroundStyle(isError ? SplickTheme.Colors.error : SplickTheme.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(SplickTheme.Spacing.md)
            .background(SplickTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium, style: .continuous))
    }

    private var shareItems: [Any]? {
        guard let paymentProfile else { return nil }
        var items: [Any] = [shareText(for: paymentProfile)]
        if let qrImage {
            items.insert(qrImage, at: 0)
        }
        return items
    }

    private func shareText(for profile: PaymentProfile) -> String {
        var lines = ["\(user.displayName) (@\(user.username))"]
        if let accountName = profile.accountName, !accountName.isEmpty {
            lines.append(accountName)
        }
        if let accountNumber = profile.accountNumber, !accountNumber.isEmpty {
            lines.append(accountNumber)
        }
        if let bankName = profile.bankName, !bankName.isEmpty {
            lines.append(bankName)
        }
        return lines.joined(separator: "\n")
    }

    private func loadQRImageIfNeeded() async {
        guard let url = paymentProfile?.qrImageURL else {
            qrImage = nil
            return
        }
        isLoadingImage = true
        defer { isLoadingImage = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            qrImage = UIImage(data: data)
        } catch {
            qrImage = nil
        }
    }

    private func saveQRImage() async {
        guard let qrImage else {
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
                PHAssetChangeRequest.creationRequestForAsset(from: qrImage)
            }) { success, _ in
                continuation.resume(returning: success)
            }
        }

        feedbackMessage = saved
            ? languageService.text(.profilePaymentImageSaved)
            : languageService.text(.profilePaymentImageSaveFailed)
    }
}

private struct PaymentProfileShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
