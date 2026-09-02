import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit
import CoreLocation
import DesignSystem
import Localization
import SplickDomain
import FeatureMedia
import FeatureFriends

private enum ComposeMetrics {
    static let fieldCornerRadius: CGFloat = SplickTheme.CornerRadius.inset
    static let companionTileWidth: CGFloat = 72
    static let companionNameWidth: CGFloat = 64
}

private enum ComposeOptionRoute: Hashable {
    case companions
    case location
}

private struct ComposeProfileRoute: Identifiable {
    let user: UserSummary
    var id: UUID { user.id }
}

public struct CreatePostComposeView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: CreatePostComposeViewModel
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    private let profileDependencies: FriendUserProfileDependencies?
    let onPostSubmit: (PreparedPostSubmit) -> Void
    let onCancel: () -> Void
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotoLibraryPicker = false
    @State private var showCameraCapture = false
    @State private var reviewingMediaID: UUID?
    @State private var showAudiencePicker = false
    @State private var profileRoute: ComposeProfileRoute?

    public init(
        viewModel: @autoclosure @escaping () -> CreatePostComposeViewModel,
        profileDependencies: FriendUserProfileDependencies? = nil,
        onPostSubmit: @escaping (PreparedPostSubmit) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.profileDependencies = profileDependencies
        self.onPostSubmit = onPostSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                mediaPreview
                captionSection
                billSplitSection
                companionsSection
                additionalOptionsSection
            }
            .padding(SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .navigationTitle(languageService.text(.feedCreateTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(languageService.text(.commonCancel), action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(languageService.text(.feedCreatePostAction)) {
                    if let prepared = viewModel.prepareSubmit() {
                        onPostSubmit(prepared)
                    }
                }
            }
        }
        .alert(
            languageService.text(.feedCreatePostFailedTitle),
            isPresented: Binding(
                get: { viewModel.submitState.error != nil },
                set: { if !$0 { viewModel.clearSubmitError() } }
            )
        ) {
            Button(languageService.text(.commonOK), role: .cancel) { viewModel.clearSubmitError() }
        } message: {
            Text(viewModel.submitState.error ?? "")
        }
        .onAppear { tabBarScrollState?.hide() }
        .onDisappear { tabBarScrollState?.show() }
        .fullScreenCover(isPresented: $showPhotoLibraryPicker) {
            MultiPhotoLibraryPickerView(
                maxSelectionCount: viewModel.remainingImageSlots,
                onConfirm: { images in
                    showPhotoLibraryPicker = false
                    viewModel.addImages(images)
                },
                onCancel: {
                    showPhotoLibraryPicker = false
                }
            )
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            MediaCaptureView(
                onMediaCaptured: { media in
                    showCameraCapture = false
                    switch media {
                    case .image(let image, _):
                        viewModel.addImages([image])
                    case .images(let images):
                        viewModel.addImages(images)
                    case .video:
                        break
                    }
                },
                onCancel: {
                    showCameraCapture = false
                }
            )
        }
        .fullScreenCover(isPresented: reviewCoverPresented) {
            if let id = reviewingMediaID,
               let image = viewModel.selectedMediaItems.first(where: { $0.id == id })?.previewImage {
                SelectedPhotoReviewView(
                    image: image,
                    onImageUpdated: { viewModel.updateMediaImage(id: id, image: $0) },
                    onDismiss: { reviewingMediaID = nil }
                )
            }
        }
        .sheet(isPresented: $showAudiencePicker) {
            PostAudiencePickerSheet(viewModel: viewModel, onUserTap: openProfile)
        }
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(user: route.user)
                )
            }
        }
        .navigationDestination(for: ComposeOptionRoute.self) { route in
            switch route {
            case .companions:
                ComposeCompanionsEditorView(viewModel: viewModel, onUserTap: openProfile)
            case .location:
                ComposeLocationEditorView(viewModel: viewModel)
            }
        }
    }

    private func openProfile(for user: UserSummary) {
        guard !viewModel.isCurrentUser(user) else { return }
        profileRoute = ComposeProfileRoute(user: user)
    }

    private var reviewCoverPresented: Binding<Bool> {
        Binding(
            get: { reviewingMediaID != nil },
            set: { if !$0 { reviewingMediaID = nil } }
        )
    }

    @ViewBuilder
    private var mediaPreview: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    ForEach(viewModel.selectedMediaItems) { item in
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let image = item.previewImage {
                                    Button {
                                        reviewingMediaID = item.id
                                    } label: {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(languageService.text(.feedCreateEditMediaA11y))
                                } else {
                                    ZStack {
                                        SplickTheme.Colors.tertiaryBackground
                                        Image(systemName: "play.rectangle.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                                    }
                                }
                            }
                            .frame(width: 140, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))

                            Button {
                                viewModel.removeMediaItem(id: item.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white, .black.opacity(0.45))
                            }
                            .padding(6)
                        }
                    }

                    if viewModel.canAddMoreMedia {
                        Menu {
                            if viewModel.remainingImageSlots > 0 {
                                Button {
                                    showCameraCapture = true
                                } label: {
                                    Label(languageService.text(.feedCreateTakePhoto), systemImage: "camera")
                                }
                                Button {
                                    showPhotoLibraryPicker = true
                                } label: {
                                    Label(languageService.text(.feedCreatePickLibrary), systemImage: "photo.on.rectangle")
                                }
                            }
                            if viewModel.remainingVideoSlots > 0 {
                                PhotosPicker(
                                    selection: $photoPickerItems,
                                    maxSelectionCount: 1,
                                    matching: .videos
                                ) {
                                    Label(languageService.text(.feedCreatePickVideo), systemImage: "video")
                                }
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 24))
                                Text(languageService.text(.feedCreateAddMedia))
                                    .font(SplickTheme.Typography.caption)
                            }
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(width: 140, height: 180)
                            .background(SplickTheme.Colors.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
                        }
                        .onChange(of: photoPickerItems) { items in
                            Task {
                                await importSelectedMediaItems(items)
                                photoPickerItems = []
                            }
                        }
                    }
                }
            }
            Text(languageService.text(.feedCreateMediaLimit))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCreateCaption))
                .font(SplickTheme.Typography.headline)
            MentionTextField(
                languageService.text(.feedCreateCaptionPlaceholder),
                text: $viewModel.caption,
                fontSize: 15,
                minHeight: 88
            )
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.tertiaryBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: ComposeMetrics.fieldCornerRadius,
                    style: .continuous
                )
            )
            .onChange(of: viewModel.caption) { newValue in
                viewModel.syncMentionPicker(with: newValue)
            }

            if let mentionViewModel = viewModel.mentionPickerViewModel {
                MentionPickerPopup(viewModel: mentionViewModel) { user in
                    viewModel.insertMention(user)
                }
            }
        }
        .splickCard()
    }

    private var additionalOptionsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCreateMoreOptions))
                .font(SplickTheme.Typography.headline)

            Button {
                showAudiencePicker = true
            } label: {
                optionRow(
                    icon: "eye",
                    title: languageService.text(.feedAudienceTitle),
                    summary: audienceOptionSummaryText
                )
            }
            .buttonStyle(.plain)

            NavigationLink(value: ComposeOptionRoute.location) {
                optionRow(
                    icon: "mappin.and.ellipse",
                    title: languageService.text(.feedCreateLocation),
                    summary: locationSummaryText
                )
            }
            .buttonStyle(.plain)
        }
        .splickCard()
    }

    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(companionsSectionTitle)
                .font(SplickTheme.Typography.headline)

            NavigationLink(value: ComposeOptionRoute.companions) {
                optionRow(
                    icon: "person.crop.circle.badge.plus",
                    title: companionsSectionTitle,
                    summary: companionsSummaryText
                )
            }
            .buttonStyle(.plain)
        }
        .splickCard()
    }

    private var audienceOptionSummaryText: String {
        "\(viewModel.audienceSummaryTitle) • \(viewModel.audienceSummarySubtitle)"
    }

    private var companionsSummaryText: String {
        let companionNames = viewModel.selectedCompanions.map(\.displayName)
            + (viewModel.enableBillSplit ? viewModel.pendingGuests.map(\.displayName) : [])

        if viewModel.enableBillSplit,
           let groupName = viewModel.selectedCompanionGroup?.name,
           !groupName.isEmpty {
            let otherCount = companionNames.count
            if otherCount == 0 {
                return groupName
            }
            return groupName + languageService.format(.feedCompanionsAndOthers, otherCount)
        }

        guard !companionNames.isEmpty else {
            return viewModel.enableBillSplit
                ? languageService.text(.feedCreateBillCompanionsHint)
                : languageService.text(.feedCreateMomentCompanionsHint)
        }

        if companionNames.count == 1 {
            return companionNames[0]
        }

        let previewNames = Array(companionNames.prefix(2))
        if companionNames.count <= 2 {
            return previewNames.joined(separator: ", ")
        }
        return previewNames.joined(separator: ", ")
            + languageService.format(.feedCompanionsAndOthers, companionNames.count - 2)
    }

    private var companionsSectionTitle: String {
        viewModel.enableBillSplit
            ? languageService.text(.feedCreateBillWith)
            : languageService.text(.feedCreateMomentWith)
    }

    private var locationSummaryText: String {
        let trimmed = viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? languageService.text(.feedCreateLocationHint) : trimmed
    }

    private func optionRow(icon: String, title: String, summary: String) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 40, height: 40)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                Text(title)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(summary)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.textTertiary)
        }
        .padding(SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private var billSplitSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            Toggle(
                languageService.text(.feedBillSplitTitle),
                isOn: Binding(
                    get: { viewModel.enableBillSplit },
                    set: { isEnabled in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.enableBillSplit = isEnabled
                        }
                    }
                )
            )
                .font(SplickTheme.Typography.headline)

            if viewModel.enableBillSplit {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                    totalAmountField

                    Picker(languageService.text(.expenseCreateSplitType), selection: $viewModel.splitMode) {
                        ForEach(ComposeBillSplitMode.allCases) { mode in
                            Text(languageService.text(mode.titleKey)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.billSplitParticipants.isEmpty && viewModel.pendingGuests.isEmpty {
                        Text(languageService.text(.feedCreateTagFriendsHint))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(SplickTheme.Spacing.sm)
                            .background(SplickTheme.Colors.tertiaryBackground)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: ComposeMetrics.fieldCornerRadius,
                                    style: .continuous
                                )
                            )
                    } else {
                        billSplitDetailFields
                    }

                    Toggle(languageService.text(.feedCreateAutoReminder), isOn: $viewModel.autoReminderEnabled)
                        .font(SplickTheme.Typography.callout)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.enableBillSplit)
        .splickCard()
    }

    private var totalAmountField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Text(languageService.text(.feedCreateTotalAmount))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(spacing: SplickTheme.Spacing.sm) {
                LiveVNDMoneyTextField(
                    text: $viewModel.billTotalText,
                    font: .systemFont(ofSize: 28, weight: .bold),
                    textColor: UIColor(SplickTheme.Colors.primaryGradientStart)
                )

                Text(languageService.text(.feedCreateCurrencySymbol))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .padding(SplickTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SplickTheme.Colors.primaryGradientStart.opacity(0.08))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: ComposeMetrics.fieldCornerRadius,
                    style: .continuous
                )
            )

            if let error = viewModel.billTotalAmountError {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
    }

    @ViewBuilder
    private var billSplitDetailFields: some View {
        switch viewModel.splitMode {
        case .equal:
            if let preview = viewModel.equalSharePreview {
                Text(preview)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SplickTheme.Spacing.sm)
                    .background(SplickTheme.Colors.tertiaryBackground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ComposeMetrics.fieldCornerRadius,
                            style: .continuous
                        )
                    )
            }
            if let share = viewModel.equalShareAmount {
                ForEach(viewModel.billSplitParticipants) { user in
                    participantAmountPreviewRow(
                        for: user,
                        amountLabel: VNDMoneyFormat.formatDisplay(share)
                    )
                }
                ForEach(viewModel.pendingGuests) { guest in
                    guestAmountPreviewRow(
                        guest,
                        amountLabel: VNDMoneyFormat.formatDisplay(share)
                    )
                }
            }

        case .percentage:
            ForEach(viewModel.billSplitParticipants) { user in
                percentageRow(for: user)
            }
            ForEach(viewModel.pendingGuests) { guest in
                percentageRow(guestId: guest.id, identity: guestIdentityView(guest))
            }

        case .exact:
            ForEach(viewModel.billSplitParticipants) { user in
                exactAmountRow(for: user)
            }
            ForEach(viewModel.pendingGuests) { guest in
                exactAmountRow(guestId: guest.id, identity: guestIdentityView(guest))
            }
        }
    }

    private func participantIdentityView(_ user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            AvatarView(
                imageURL: user.avatarURL,
                name: user.displayName,
                size: .small
            )

            Text(viewModel.participantDisplayName(user))
                .font(SplickTheme.Typography.callout)
                .fontWeight(viewModel.isCurrentUser(user) ? .semibold : .regular)
                .foregroundStyle(
                    viewModel.isCurrentUser(user)
                        ? SplickTheme.Colors.primaryGradientStart
                        : SplickTheme.Colors.textPrimary
                )
                .lineLimit(1)
        }
    }

    private func participantAmountPreviewRow(for user: UserSummary, amountLabel: String) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            participantIdentityView(user)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(amountLabel)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(
                    viewModel.isCurrentUser(user)
                        ? SplickTheme.Colors.primaryGradientStart
                        : SplickTheme.Colors.textSecondary
                )
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private func guestIdentityView(_ guest: ComposePendingGuest) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            AvatarView(
                name: guest.displayName,
                size: .small,
                placeholder: .brand
            )
            Text(guest.displayName)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
        }
    }

    private func guestAmountPreviewRow(_ guest: ComposePendingGuest, amountLabel: String) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            guestIdentityView(guest)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(amountLabel)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private func percentageRow(for user: UserSummary) -> some View {
        percentageRow(guestId: user.id, identity: participantIdentityView(user))
    }

    private func percentageRow<Identity: View>(guestId: UUID, identity: Identity) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            identity
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                TextField("0", text: percentBinding(for: guestId))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 48)
                Text("%")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .frame(width: 72)

            Text(percentageAmountLabel(for: guestId))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private func exactAmountRow(for user: UserSummary) -> some View {
        exactAmountRow(guestId: user.id, identity: participantIdentityView(user))
    }

    private func exactAmountRow<Identity: View>(guestId: UUID, identity: Identity) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            identity

            Spacer()

            HStack(spacing: 4) {
                LiveVNDMoneyTextField(
                    text: exactAmountBinding(for: guestId),
                    font: .systemFont(ofSize: 16, weight: .medium),
                    textColor: UIColor(SplickTheme.Colors.textPrimary)
                )
                .frame(minWidth: 100)

                Text(languageService.text(.feedCreateCurrencySymbol))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private func percentageAmountLabel(for userId: UUID) -> String {
        guard let amount = viewModel.amountForPercentage(userId: userId) else {
            return "— " + languageService.text(.feedCreateCurrencySymbol)
        }
        return VNDMoneyFormat.formatDisplay(amount)
    }

    private func percentBinding(for userId: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.percentageTexts[userId] ?? "" },
            set: { viewModel.percentageTexts[userId] = $0.filter { $0.isNumber || $0 == "," || $0 == "." } }
        )
    }

    private func exactAmountBinding(for userId: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.exactAmountTexts[userId] ?? "" },
            set: { viewModel.exactAmountTexts[userId] = $0 }
        )
    }

    @MainActor
    private func importSelectedMediaItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard viewModel.canAddMoreMedia else { break }
            let isVideo = item.supportedContentTypes.contains(where: { $0.conforms(to: UTType.movie) })
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }

            if isVideo {
                viewModel.addMediaDraft(
                    ComposeMediaDraft(
                        previewImage: nil,
                        mediaType: .video,
                        data: data,
                        mimeType: "video/mp4",
                        videoDurationSeconds: nil
                    )
                )
            } else {
                guard let image = UIImage(data: data) else { continue }
                viewModel.addMediaDraft(
                    ComposeMediaDraft(
                        previewImage: image,
                        mediaType: .image,
                        data: data,
                        mimeType: "image/jpeg",
                        videoDurationSeconds: nil
                    )
                )
            }
        }
    }
}

private struct ComposeCompanionsEditorView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let onUserTap: (UserSummary) -> Void
    @FocusState private var isFriendSearchFocused: Bool
    @State private var showAddGuestSheet = false

    private var companionsTitle: String {
        viewModel.enableBillSplit
            ? languageService.text(.feedCreateBillWith)
            : languageService.text(.feedCreateMomentWith)
    }

    private var friendSearchPlaceholder: String {
        viewModel.enableBillSplit
            ? languageService.text(.feedCreateSearchFriendsGroups)
            : languageService.text(.feedCreateSearchFriends)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    Text(companionsTitle)
                        .font(SplickTheme.Typography.headline)

                    HStack(spacing: SplickTheme.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                        TextField(friendSearchPlaceholder, text: $viewModel.friendSearchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isFriendSearchFocused)
                            .onChange(of: isFriendSearchFocused) { focused in
                                viewModel.setFriendSearchActive(focused)
                            }
                            .onChange(of: viewModel.friendSearchQuery) { query in
                                viewModel.updateFriendSearch(query)
                            }
                    }
                    .padding(SplickTheme.Spacing.sm)
                    .background(SplickTheme.Colors.tertiaryBackground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ComposeMetrics.fieldCornerRadius,
                            style: .continuous
                        )
                    )

                    if viewModel.enableBillSplit, let group = viewModel.selectedCompanionGroup {
                        selectedCompanionGroupCard(group)
                    }

                    if !viewModel.selectedCompanions.isEmpty || !viewModel.pendingGuests.isEmpty {
                        selectedCompanionsStrip
                    }

                    if viewModel.enableBillSplit {
                        addGuestWithoutAppButton
                    }

                    if viewModel.enableBillSplit || viewModel.shouldShowFriendSuggestions {
                        friendSearchResultsList
                    }
                }
                .splickCard()
            }
            .padding(SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .navigationTitle(companionsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.preloadFriendSuggestionsIfNeeded()
            if viewModel.enableBillSplit {
                await viewModel.loadCompanionGroupsIfNeeded()
            }
        }
        .sheet(isPresented: $showAddGuestSheet) {
            AddGuestWithoutAppSheet { email in
                viewModel.addPendingGuest(displayName: "", email: email)
            }
            .environmentObject(languageService)
        }
    }

    private var addGuestWithoutAppButton: some View {
        Button {
            showAddGuestSheet = true
        } label: {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "plus.circle.fill")
                Text(languageService.text(.feedCreateGuestSection))
                    .font(SplickTheme.Typography.callout)
            }
            .foregroundStyle(SplickTheme.Colors.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.feedCreateGuestSection))
    }

    private var selectedCompanionsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                ForEach(viewModel.selectedCompanions) { friend in
                    selectedCompanionTile(for: friend)
                }
                ForEach(viewModel.pendingGuests) { guest in
                    selectedGuestTile(for: guest)
                }
            }
            .padding(.vertical, SplickTheme.Spacing.xxxs)
        }
    }

    private func selectedGuestTile(for guest: ComposePendingGuest) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                AvatarView(
                    name: guest.displayName,
                    size: .medium,
                    placeholder: .brand
                )
                .overlay {
                    Circle()
                        .strokeBorder(
                            SplickTheme.Colors.primaryGradientStart.opacity(0.18),
                            lineWidth: 1
                        )
                }

                Button {
                    viewModel.removePendingGuest(guest)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .accessibilityLabel(
                    languageService.format(.feedCreateGuestRemoveA11y, guest.displayName)
                )
            }

            Text(guest.displayName)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(width: ComposeMetrics.companionNameWidth)
        }
        .frame(width: ComposeMetrics.companionTileWidth)
        .padding(.vertical, SplickTheme.Spacing.xxs)
    }

    private func selectedCompanionTile(for friend: UserSummary) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                Button {
                    onUserTap(friend)
                } label: {
                    AvatarView(
                        imageURL: friend.avatarURL,
                        name: friend.displayName,
                        size: .medium
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(
                                SplickTheme.Colors.primaryGradientStart.opacity(0.18),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.removeCompanion(friend)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }

            Button {
                onUserTap(friend)
            } label: {
                Text(companionShortName(friend))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .frame(width: ComposeMetrics.companionNameWidth)
            }
            .buttonStyle(.plain)
        }
        .frame(width: ComposeMetrics.companionTileWidth)
        .padding(.vertical, SplickTheme.Spacing.xxs)
    }

    @ViewBuilder
    private var friendSearchResultsList: some View {
        VStack(spacing: 0) {
            let showsGroups = viewModel.enableBillSplit && !viewModel.filteredCompanionGroups.isEmpty
            let showsFriends = !viewModel.friendSearchResults.isEmpty

            if !showsGroups && !showsFriends {
                if viewModel.isSearchingFriends {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.md)
                } else {
                    Text(languageService.text(.feedCreateFriendsNotFound))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SplickTheme.Spacing.sm)
                }
            } else {
                if showsGroups {
                    groupSearchResultsSection
                }

                if showsGroups && showsFriends {
                    Divider().padding(.leading, 48)
                }

                ForEach(viewModel.friendSearchResults) { friend in
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        Button {
                            viewModel.addCompanion(friend)
                        } label: {
                            HStack(spacing: SplickTheme.Spacing.sm) {
                                AvatarView(
                                    imageURL: friend.avatarURL,
                                    name: friend.displayName,
                                    size: .small
                                )
                                .frame(width: 32, height: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(SplickTheme.Typography.callout)
                                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                                    Text("@\(friend.username)")
                                        .font(SplickTheme.Typography.caption)
                                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.addCompanion(friend)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                    .onAppear {
                        viewModel.loadMoreFriendSearchIfNeeded(currentFriend: friend)
                    }

                    if friend.id != viewModel.friendSearchResults.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }

                if viewModel.isSearchingFriends {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                }
            }
        }
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private var groupSearchResultsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text(languageService.text(.friendsTabGroups))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                Spacer()
            }
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.top, SplickTheme.Spacing.sm)
            .padding(.bottom, SplickTheme.Spacing.xxs)

            ForEach(viewModel.filteredCompanionGroups) { group in
                Button {
                    viewModel.selectCompanionGroup(group)
                } label: {
                    companionGroupRow(group)
                }
                .buttonStyle(.plain)

                if group.id != viewModel.filteredCompanionGroups.last?.id {
                    Divider().padding(.leading, 48)
                }
            }
        }
    }

    private func selectedCompanionGroupCard(_ group: SplickDomain.Group) -> some View {
        let displayCount = group.members.isEmpty ? group.memberCount : group.members.count
        return VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    .frame(width: 40, height: 40)
                    .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    viewModel.toggleCompanionGroupMembersExpanded()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                        Text(languageService.format(.friendsMemberCount, displayCount))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                        HStack(spacing: 4) {
                            Text(
                                languageService.text(
                                    viewModel.companionGroupMembersExpanded
                                        ? .feedCreateHideGroupMembers
                                        : .feedCreateShowGroupMembers
                                )
                            )
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            if viewModel.isLoadingCompanionGroupMembers {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(
                                    systemName: viewModel.companionGroupMembersExpanded
                                        ? "chevron.up"
                                        : "chevron.down"
                                )
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.removeCompanionGroup()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            if viewModel.companionGroupMembersExpanded, !group.members.isEmpty {
                VStack(spacing: SplickTheme.Spacing.xs) {
                    ForEach(group.members) { member in
                        companionGroupMemberRow(member)
                    }
                }
            }
        }
        .padding(SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: ComposeMetrics.fieldCornerRadius,
                style: .continuous
            )
        )
    }

    private func companionGroupMemberRow(_ member: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: member.avatarURL,
                name: member.displayName,
                size: .small
            )
            Text(
                viewModel.isCurrentUser(member)
                    ? languageService.text(.commonMe)
                    : member.displayName
            )
            .font(SplickTheme.Typography.callout)
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .lineLimit(1)

            Spacer(minLength: 0)

            if !viewModel.isCurrentUser(member) {
                Button {
                    viewModel.removeCompanionGroupMember(member)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func companionGroupRow(_ group: SplickDomain.Group) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .frame(width: 40, height: 40)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Text(languageService.format(.friendsMemberCount, group.memberCount))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, 10)
    }

    private func companionShortName(_ user: UserSummary) -> String {
        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return user.username }
        let shortName = trimmedName.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? trimmedName
        return shortName
    }
}

private struct ComposeLocationEditorView: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: CreatePostComposeViewModel
    @StateObject private var locationProvider = WhenInUseLocationProvider()

    var body: some View {
        List {
            Section {
                SplickTextField(languageService.text(.feedCreateLocationPlaceholder), text: $viewModel.location)
                    .onChange(of: viewModel.location) { _ in
                        viewModel.locationQueryDidChange()
                    }
                if !viewModel.locationGpsAvailable {
                    Text(languageService.text(.feedCreateLocationEnableGps))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            } header: {
                Text(languageService.text(.feedCreateLocation))
            }

            if showsCustomPlaceRow {
                Section {
                    Button {
                        viewModel.useTypedLocation()
                    } label: {
                        Text(languageService.format(.feedCreateLocationUseTyped, trimmedQuery))
                    }
                }
            }

            if trimmedQuery.count >= 2, !viewModel.searchPlaces.isEmpty {
                Section(languageService.text(.feedCreateLocationSearchResults)) {
                    ForEach(viewModel.searchPlaces, id: \.self) { place in
                        placeButton(place)
                    }
                }
            }

            if trimmedQuery.count < 2, !viewModel.nearbyPlaces.isEmpty {
                Section(languageService.text(.feedCreateLocationNearby)) {
                    ForEach(viewModel.nearbyPlaces, id: \.self) { place in
                        placeButton(place)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(languageService.text(.feedCreateLocation))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { locationProvider.request() }
        .onReceive(locationProvider.$coordinate) { coordinate in
            if let coordinate {
                viewModel.onDeviceCoordinates(lat: coordinate.latitude, lon: coordinate.longitude)
            }
        }
        .onReceive(locationProvider.$didFinishRequest) { finished in
            if finished, locationProvider.coordinate == nil {
                viewModel.onLocationPermissionDenied()
            }
        }
    }

    private var trimmedQuery: String {
        viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsCustomPlaceRow: Bool {
        trimmedQuery.count >= 2
            && viewModel.searchPlaces.contains(where: {
                $0.displayName.caseInsensitiveCompare(trimmedQuery) == .orderedSame
            }) == false
            && viewModel.selectedPlace?.displayName != trimmedQuery
    }

    private func placeButton(_ place: PostPlace) -> some View {
        Button {
            viewModel.selectPlace(place)
        } label: {
            HStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                Text(place.displayName)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
        }
    }
}

private struct AddGuestWithoutAppSheet: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @State private var guestEmail = ""
    @FocusState private var isEmailFocused: Bool
    let onAdd: (String) -> Void

    private var canAdd: Bool {
        let email = guestEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        return email.contains("@") && email.contains(".")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                TextField(languageService.text(.feedCreateGuestPhonePlaceholder), text: $guestEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)
                    .focused($isEmailFocused)
                    .padding(SplickTheme.Spacing.sm)
                    .background(SplickTheme.Colors.tertiaryBackground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ComposeMetrics.fieldCornerRadius,
                            style: .continuous
                        )
                    )

                Spacer()
            }
            .padding(SplickTheme.Spacing.md)
            .navigationTitle(languageService.text(.feedCreateGuestSection))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(languageService.text(.feedCreateGuestAddAction)) {
                        onAdd(guestEmail)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canAdd)
                }
            }
            .onAppear { isEmailFocused = true }
        }
        .presentationDetents([.medium])
    }
}

@MainActor
private final class WhenInUseLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var didFinishRequest = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            didFinishRequest = true
            coordinate = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            break
        default:
            didFinishRequest = true
            coordinate = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
        didFinishRequest = true
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        didFinishRequest = true
        if coordinate == nil {
            coordinate = nil
        }
    }
}
