import SwiftUI
import UIKit
import CoreLocation
import Common
import DesignSystem
import Localization
import SplickDomain
import FeatureMedia
import FeatureFriends

private enum ComposeMetrics {
    static let fieldCornerRadius: CGFloat = SplickTheme.CornerRadius.inset
    static let companionTileWidth: CGFloat = 72
    static let companionNameWidth: CGFloat = 64
    static let searchResultsMaxHeight: CGFloat = 240
    static let actionChipHeight: CGFloat = 36
    static let mediaCardSpacing: CGFloat = 12
    static let mediaCardPeek: CGFloat = 40
    static let mediaCardCornerRadius: CGFloat = 20

    static var mediaCardWidth: CGFloat {
        max(UIScreen.main.bounds.width - SplickTheme.Spacing.md - mediaCardPeek, 280)
    }

    static var mediaCardHeight: CGFloat {
        min(mediaCardWidth * 1.22, 540)
    }
}

enum ComposeSearchAnchor: Hashable {
    case companions
    case audience
}

func revealComposeSearch(_ proxy: ScrollViewProxy, _ id: ComposeSearchAnchor) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
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
    private let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    private let stickerPickerBuilder: MediaStickerPickerBuilder?
    let onPostSubmit: (PreparedPostSubmit) -> Void
    let onCancel: () -> Void
    @State private var showPhotoLibraryPicker = false
    @State private var showCameraCapture = false
    @State private var reviewingMediaID: UUID?
    @State private var showBillSplitScreen = false
    @State private var showCompanionsScreen = false
    @State private var showAudienceScreen = false
    @State private var showLocationScreen = false
    @State private var profileRoute: ComposeProfileRoute?

    public init(
        viewModel: @autoclosure @escaping () -> CreatePostComposeViewModel,
        profileDependencies: FriendUserProfileDependencies? = nil,
        nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol? = nil,
        stickerPickerBuilder: MediaStickerPickerBuilder? = nil,
        onPostSubmit: @escaping (PreparedPostSubmit) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.profileDependencies = profileDependencies
        self.nearbyDiscoveryUseCase = nearbyDiscoveryUseCase
        self.stickerPickerBuilder = stickerPickerBuilder
        self.onPostSubmit = onPostSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                    composerIdentity
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        .padding(.top, SplickTheme.Spacing.sm)
                    composeActionPills
                    captionComposer
                        .padding(.horizontal, SplickTheme.Spacing.md)
                    mediaPreview
                }
                .padding(.bottom, SplickTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.immediately)
            composeBottomBar
        }
        .background(SplickTheme.Colors.background)
        .navigationTitle(languageService.text(.feedCreateTitle))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showBillSplitScreen) {
            ComposeBillSplitView(
                viewModel: viewModel,
                nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                profileDependencies: profileDependencies,
                onUserTap: openProfile
            )
        }
        .navigationDestination(isPresented: $showCompanionsScreen) {
            ComposeCompanionsEditorView(
                viewModel: viewModel,
                onUserTap: openProfile,
                nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                profileDependencies: profileDependencies
            )
        }
        .navigationDestination(isPresented: $showAudienceScreen) {
            ComposeAudienceScreen(
                viewModel: viewModel,
                onUserTap: openProfile
            )
        }
        .navigationDestination(isPresented: $showLocationScreen) {
            ComposeLocationEditorView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    PhotoEditorSessionStore.shared.removeAll()
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                }
                .accessibilityLabel(languageService.text(.commonCancel))
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
        .onAppear {
            tabBarScrollState?.hide()
            viewModel.startCompanionDirectoryLoadIfNeeded()
        }
        .onDisappear {
            guard !isPresentingComposeOptionScreen else { return }
            tabBarScrollState?.show()
        }
        .fullScreenCover(isPresented: $showPhotoLibraryPicker) {
            MultiPhotoLibraryPickerView(
                maxSelectionCount: viewModel.remainingMediaSlots,
                onConfirm: { items in
                    showPhotoLibraryPicker = false
                    for item in items {
                        switch item {
                        case .image(let image):
                            viewModel.addImages([image])
                        case .video(let url):
                            viewModel.addVideo(url: url)
                        }
                    }
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
                    case .video(let url):
                        viewModel.addVideo(url: url)
                    case .pendingVideo(let pending):
                        viewModel.addPendingVideoEncode(pending)
                    case .mixed(let images, let videos):
                        viewModel.addImages(images)
                        for url in videos {
                            viewModel.addVideo(url: url)
                        }
                    }
                },
                onCancel: {
                    showCameraCapture = false
                },
                stickerPickerBuilder: stickerPickerBuilder,
                maxLibrarySelection: viewModel.remainingMediaSlots
            )
            .environmentObject(CameraOpenRevealProgressSource(value: 1))
        }
        .fullScreenCover(isPresented: reviewCoverPresented) {
            if let id = reviewingMediaID,
               let item = viewModel.selectedMediaItems.first(where: { $0.id == id }) {
                if item.mediaType == .video, let url = item.previewPlaybackURL {
                    SelectedVideoReviewView(
                        url: url,
                        onDismiss: { reviewingMediaID = nil }
                    )
                } else if let image = item.previewImage, item.mediaType == .image {
                    SelectedPhotoReviewView(
                        image: image,
                        sessionId: id,
                        stickerPickerBuilder: stickerPickerBuilder,
                        onImageUpdated: { viewModel.updateMediaImage(id: id, image: $0) },
                        onDismiss: { reviewingMediaID = nil }
                    )
                }
            }
        }
        .sheet(item: $profileRoute) { route in
            if let profileDependencies {
                FriendUserProfileView(
                    viewModel: profileDependencies.makeViewModel(user: route.user)
                )
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
        let cardWidth = ComposeMetrics.mediaCardWidth
        let cardHeight = ComposeMetrics.mediaCardHeight
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ComposeMetrics.mediaCardSpacing) {
                    ForEach(Array(viewModel.selectedMediaItems.enumerated()), id: \.element.id) { index, item in
                        composeMediaCard(item: item, width: cardWidth, height: cardHeight)
                            .overlay(alignment: .bottomLeading) {
                                if index == 0, viewModel.canAddMoreMedia {
                                    addMediaOverlayChip
                                        .padding(SplickTheme.Spacing.sm)
                                }
                            }
                    }

                    if viewModel.selectedMediaItems.isEmpty, viewModel.canAddMoreMedia {
                        addMediaPlaceholderCard(width: cardWidth, height: cardHeight)
                    }
                }
                .padding(.leading, SplickTheme.Spacing.md)
                .padding(.trailing, SplickTheme.Spacing.sm)
            }

            Text(languageService.text(.feedCreateMediaLimit))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textTertiary)
                .padding(.horizontal, SplickTheme.Spacing.md)
        }
    }

    private func composeMediaCard(item: ComposeMediaDraft, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                guard !item.isEncoding else { return }
                if item.previewImage != nil || item.mediaType == .video {
                    reviewingMediaID = item.id
                }
            } label: {
                Group {
                    if let image = item.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        SplickTheme.Colors.tertiaryBackground
                    }
                }
                .overlay(alignment: .center) {
                    if item.isEncoding, let progress = item.encodingProgress {
                        encodingOverlay(progress: progress)
                    } else if item.mediaType == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 4, y: 1)
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            }
            .buttonStyle(.plain)
            .disabled(item.isEncoding)
            .accessibilityLabel(
                item.mediaType == .video
                    ? languageService.text(.mediaTypeVideo)
                    : languageService.text(.feedCreateEditMediaA11y)
            )

            Button {
                viewModel.removeMediaItem(id: item.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.45))
            }
            .padding(10)
        }
        .frame(width: width, height: height)
        .clipShape(
            RoundedRectangle(cornerRadius: ComposeMetrics.mediaCardCornerRadius, style: .continuous)
        )
    }

    private func addMediaPlaceholderCard(width: CGFloat, height: CGFloat) -> some View {
        addMediaMenu {
            VStack(spacing: SplickTheme.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 32, weight: .semibold))
                Text(languageService.text(.feedCreateAddMedia))
                    .font(SplickTheme.Typography.callout)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(width: width, height: height)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(
                RoundedRectangle(cornerRadius: ComposeMetrics.mediaCardCornerRadius, style: .continuous)
            )
        }
    }

    private var addMediaOverlayChip: some View {
        addMediaMenu {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                Text(languageService.text(.feedCreateAddMedia))
                    .font(SplickTheme.Typography.captionBold)
                    .lineLimit(1)
            }
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
        }
    }

    private func addMediaMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
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
        } label: {
            label()
        }
    }

    private func encodingOverlay(progress: Double) -> some View {
        let percent = min(max(Int((progress * 100).rounded(.down)), 0), 99)
        return ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .tint(.white)
                    .frame(width: 56)
                Text("\(percent)%")
                    .font(SplickTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }

    private var composerIdentity: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: viewModel.composerUser?.avatarURL,
                name: viewModel.composerUser?.displayName ?? "",
                size: .medium
            )
            Text(viewModel.composerUser?.displayName ?? "")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var captionComposer: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            MentionTextField(
                languageService.text(.feedCreateCaptionPlaceholder),
                text: $viewModel.caption,
                fontSize: 20,
                minHeight: 52,
                displayNamesByUsername: viewModel.mentionDisplayNamesByKey,
                displayNamesByUserId: viewModel.mentionDisplayNamesByUserId
            )
            .onChange(of: viewModel.caption) { newValue in
                viewModel.syncMentionPicker(with: newValue)
            }

            if !viewModel.caption.isEmpty {
                Text("\(PostCaption.characterCount(viewModel.caption))/\(PostCaption.maxLength)")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(
                        viewModel.isCaptionAtLimit
                            ? SplickTheme.Colors.error
                            : SplickTheme.Colors.textTertiary
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let mentionViewModel = viewModel.mentionPickerViewModel {
                MentionPickerPopup(viewModel: mentionViewModel) { user in
                    viewModel.insertMention(user)
                }
            }
        }
    }

    private var isPresentingComposeOptionScreen: Bool {
        showBillSplitScreen || showCompanionsScreen || showAudienceScreen || showLocationScreen
    }

    private var composeActionPills: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ComposeOptionPill(
                        title: languageService.text(.feedBillSplitTitle),
                        systemImage: "banknote.fill",
                        isActive: viewModel.enableBillSplit
                    ) {
                        openBillSplitScreen()
                    }
                    ComposeOptionPill(
                        title: languageService.text(.feedCreateTagFriends),
                        systemImage: "person.2.fill",
                        isActive: hasSelectedCompanions
                    ) {
                        openCompanionsScreen()
                    }
                    ComposeOptionPill(
                        title: languageService.text(.feedCreateLocation),
                        systemImage: "mappin.and.ellipse",
                        isActive: hasSelectedLocation
                    ) {
                        openLocationScreen()
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
            }

            if hasComposeOptionSummaries {
                composeOptionSummaries
                    .padding(.horizontal, SplickTheme.Spacing.md)
            }
        }
    }

    private var composeBottomBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.55)
            HStack(spacing: SplickTheme.Spacing.sm) {
                Button(action: openAudienceScreen) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.audienceSummaryTitle)
                            .font(SplickTheme.Typography.callout)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: SplickTheme.Spacing.sm)

                Button(action: submitPost) {
                    Text(languageService.text(.feedCreatePostAction))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.canSubmitPost
                                ? SplickTheme.Colors.brandBlue
                                : SplickTheme.Colors.brandBlue.opacity(0.35)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(SplickTheme.Colors.background)
            .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
        }
    }

    private func submitPost() {
        hideKeyboard()
        if let prepared = viewModel.prepareSubmit() {
            PhotoEditorSessionStore.shared.removeAll()
            onPostSubmit(prepared)
        }
    }

    private var composeOptionSummaries: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            if viewModel.enableBillSplit, !billRowSummaryText.isEmpty {
                composeSummaryChip(text: billRowSummaryText, tint: SplickTheme.Colors.success)
            } else if hasSelectedCompanions {
                composeSummaryChip(text: companionsSummaryText, tint: SplickTheme.Colors.brandBlue)
            }

            if hasSelectedLocation {
                composeSummaryChip(text: locationSummaryText, tint: SplickTheme.Colors.brandOrange)
            }
        }
    }

    private func composeSummaryChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func openBillSplitScreen() {
        hideKeyboard()
        viewModel.startCompanionDirectoryLoadIfNeeded()
        showBillSplitScreen = true
    }

    private func openCompanionsScreen() {
        hideKeyboard()
        if viewModel.enableBillSplit {
            showBillSplitScreen = true
            return
        }
        viewModel.startCompanionDirectoryLoadIfNeeded()
        showCompanionsScreen = true
    }

    private func openAudienceScreen() {
        hideKeyboard()
        showAudienceScreen = true
    }

    private func openLocationScreen() {
        hideKeyboard()
        showLocationScreen = true
    }

    private var hasSelectedCompanions: Bool {
        !viewModel.selectedCompanions.isEmpty
            || !viewModel.selectedCompanionGroups.isEmpty
            || !viewModel.pendingGuests.isEmpty
    }

    private var hasSelectedLocation: Bool {
        !viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasComposeOptionSummaries: Bool {
        (viewModel.enableBillSplit && !billRowSummaryText.isEmpty)
            || (!viewModel.enableBillSplit && hasSelectedCompanions)
            || hasSelectedLocation
    }

    private var companionsSummaryText: String {
        let companionNames = viewModel.selectedCompanions.map(\.displayName)
            + viewModel.pendingGuests.map(\.displayName)

        if let groupName = viewModel.companionGroupDisplayName,
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

    private var billRowSummaryText: String {
        guard viewModel.enableBillSplit else { return "" }
        if let total = viewModel.parsedBillTotal {
            return VNDMoneyFormat.formatDisplay(total)
        }
        guard hasSelectedCompanions else { return "" }
        return companionsSummaryText
    }

    private var locationSummaryText: String {
        let trimmed = viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? languageService.text(.feedCreateLocationHint) : trimmed
    }
}

private struct ComposeOptionPill: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? SplickTheme.Colors.brandBlue.opacity(0.12)
                            : SplickTheme.Colors.secondaryBackground
                    )
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isActive
                            ? SplickTheme.Colors.brandBlue.opacity(0.35)
                            : SplickTheme.Colors.divider.opacity(0.7),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isActive ? AccessibilityTraits.isSelected : [])
    }
}

private struct ComposeAudienceScreen: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let onUserTap: (UserSummary) -> Void

    var body: some View {
        ScrollView {
            PostAudiencePickerSheet(
                viewModel: viewModel,
                onUserTap: onUserTap,
                embedded: true
            )
            .padding(SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
        .dismissKeyboardOnTap()
        .navigationTitle(languageService.text(.feedAudienceTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(languageService.text(.commonDone)) {
                    dismiss()
                }
            }
        }
    }
}

private struct ComposeBillSplitView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    let onUserTap: (UserSummary) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                totalAmountField

                Toggle(languageService.text(.feedCreateAutoReminder), isOn: $viewModel.autoReminderEnabled)
                    .font(SplickTheme.Typography.callout)

                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    Text(languageService.text(.expenseCreateSplitType))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)

                    Picker(languageService.text(.expenseCreateSplitType), selection: $viewModel.splitMode) {
                        ForEach(ComposeBillSplitMode.allCases) { mode in
                            Text(languageService.text(mode.titleKey)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(languageService.text(.feedCreateBillWith))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)

                ComposeCompanionsEditorView(
                    viewModel: viewModel,
                    onUserTap: onUserTap,
                    nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                    profileDependencies: profileDependencies,
                    embedded: true,
                    billMode: true
                )

                if !viewModel.billSplitParticipants.isEmpty || !viewModel.pendingGuests.isEmpty {
                    billSplitDetailFields
                }
            }
            .splickCard()
            .padding(SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .background(SplickTheme.Colors.secondaryBackground)
        .scrollDismissesKeyboard(.immediately)
        .dismissKeyboardOnTap()
        .navigationTitle(languageService.text(.feedBillSplitTitle))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(languageService.text(.commonDone)) {
                    dismiss()
                }
            }
        }
    }

    private var totalAmountField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxs) {
            Text(languageService.text(.feedCreateTotalAmount))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(spacing: SplickTheme.Spacing.sm) {
                LiveVNDMoneyTextField(
                    text: $viewModel.billTotalText,
                    font: .systemFont(ofSize: 22, weight: .bold),
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
                TextField("-", text: percentBinding(for: guestId))
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
                    textColor: UIColor(SplickTheme.Colors.textPrimary),
                    placeholder: "-"
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
            set: { viewModel.setPercentage(userId: userId, raw: $0) }
        )
    }

    private func exactAmountBinding(for userId: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.exactAmountTexts[userId] ?? "" },
            set: { viewModel.setExactAmount(userId: userId, raw: $0) }
        )
    }
}

private struct ComposeCompanionsEditorView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let onUserTap: (UserSummary) -> Void
    let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    var embedded: Bool = false
    var billMode: Bool = false
    var onSearchFocused: (() -> Void)? = nil
    @FocusState private var isFriendSearchFocused: Bool
    @State private var showAddGuestSheet = false
    @State private var isBillSearchExpanded = false
    @State private var keepBillSearchOpen = false

    private var isBillCompanionMode: Bool {
        billMode || viewModel.enableBillSplit
    }

    private var companionsTitle: String {
        isBillCompanionMode
            ? languageService.text(.feedCreateBillWith)
            : languageService.text(.feedCreateMomentWith)
    }

    private var friendSearchPlaceholder: String {
        languageService.text(.feedCreateSearchFriendsGroups)
    }

    private var showsFriendSearchResults: Bool {
        if billMode {
            return isBillSearchExpanded
        }
        return viewModel.shouldShowFriendSuggestions
    }

    var body: some View {
        Group {
            if embedded {
                companionFields
                    .onChange(of: isFriendSearchFocused) { focused in
                        handleFriendSearchFocus(focused) {
                            onSearchFocused?()
                        }
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                            VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                                Text(companionsTitle)
                                    .font(SplickTheme.Typography.headline)
                                companionFields
                            }
                            .splickCard()
                        }
                        .padding(SplickTheme.Spacing.md)
                        .padding(.bottom, SplickTheme.Spacing.xl)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .dismissKeyboardOnTap()
                    .navigationTitle(companionsTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(languageService.text(.commonDone)) {
                                dismiss()
                            }
                        }
                    }
                    .onChange(of: isFriendSearchFocused) { focused in
                        handleFriendSearchFocus(focused) {
                            revealComposeSearch(proxy, .companions)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.startCompanionDirectoryLoadIfNeeded()
        }
        .sheet(isPresented: $showAddGuestSheet) {
            AddGuestWithoutAppSheet { email in
                viewModel.addPendingGuest(displayName: "", email: email)
            }
            .environmentObject(languageService)
        }
    }

    @ViewBuilder
    private var companionFields: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    if !viewModel.selectedCompanionGroups.isEmpty {
                        ForEach(viewModel.selectedCompanionGroups) { group in
                            selectedCompanionGroupCard(group)
                        }
                    }

                    if !viewModel.selectedCompanions.isEmpty || !viewModel.pendingGuests.isEmpty {
                        selectedCompanionsStrip
                    }

                    if isBillCompanionMode {
                        billShareAddActions
                    }

                    VStack(spacing: 0) {
                        HStack(spacing: SplickTheme.Spacing.xs) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                            TextField(friendSearchPlaceholder, text: $viewModel.friendSearchQuery)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isFriendSearchFocused)
                                .onChange(of: viewModel.friendSearchQuery) { query in
                                    viewModel.updateFriendSearch(query)
                                }
                        }
                        .padding(SplickTheme.Spacing.sm)

                        if showsFriendSearchResults {
                            VStack(spacing: 0) {
                                Divider()
                                friendSearchResultsList
                            }
                            .transition(
                                .asymmetric(
                                    insertion: AnyTransition.opacity.combined(
                                        with: .move(edge: .top)
                                    ),
                                    removal: AnyTransition.opacity.combined(
                                        with: .move(edge: .top)
                                    )
                                )
                            )
                        }
                    }
                    .id(ComposeSearchAnchor.companions)
                    .background(SplickTheme.Colors.tertiaryBackground)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ComposeMetrics.fieldCornerRadius,
                            style: .continuous
                        )
                    )
                    .animation(
                        .spring(response: 0.34, dampingFraction: 0.86),
                        value: showsFriendSearchResults
                    )
        }
    }

    private func handleFriendSearchFocus(_ focused: Bool, reveal: () -> Void) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            viewModel.setFriendSearchActive(focused)
            guard billMode else { return }
            if focused {
                isBillSearchExpanded = true
            } else if !keepBillSearchOpen {
                isBillSearchExpanded = false
            }
        }
        if focused {
            reveal()
        }
    }

    private func addCompanionAndDismissSearch(_ friend: UserSummary) {
        viewModel.addCompanion(friend)
        guard billMode else {
            isFriendSearchFocused = false
            hideKeyboard()
            return
        }
        keepBillSearchOpen = true
        isBillSearchExpanded = true
        DispatchQueue.main.async {
            isFriendSearchFocused = true
            keepBillSearchOpen = false
        }
    }

    private var billShareAddActions: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            if let nearbyDiscoveryUseCase, let profileDependencies {
                ComposeNearbyRadarButton(
                    nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                    profileDependencies: profileDependencies,
                    languageService: languageService,
                    selectedCompanionIds: viewModel.selectedCompanionIds.union(
                        viewModel.selectedCompanionGroupMemberIds
                    ),
                    onAddCompanion: { user in
                        viewModel.addCompanion(user)
                    },
                    onRemoveCompanion: { user in
                        viewModel.removeCompanion(user)
                    }
                )
            }
            addGuestWithoutAppButton
        }
    }

    private var addGuestWithoutAppButton: some View {
        Button {
            showAddGuestSheet = true
        } label: {
            BillShareActionChip(
                title: languageService.text(.feedCreateGuestChip),
                systemImage: "plus.circle.fill"
            )
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
        ScrollView {
        LazyVStack(spacing: 0) {
            let showsGroups = !viewModel.filteredCompanionGroups.isEmpty
            let showsFriends = !viewModel.friendSearchResults.isEmpty

            if !showsGroups && !showsFriends {
                if viewModel.isSearchingFriends {
                    SplickSpinner(size: .small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.md)
                } else if !viewModel.friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                            addCompanionAndDismissSearch(friend)
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
                            addCompanionAndDismissSearch(friend)
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
                    SplickSpinner(size: .small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.sm)
                }
            }
        }
        }
        .frame(maxHeight: ComposeMetrics.searchResultsMaxHeight)
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
                    isFriendSearchFocused = false
                    hideKeyboard()
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
        HStack(spacing: SplickTheme.Spacing.sm) {
            AvatarView(
                imageURL: group.avatarURL,
                name: group.name,
                size: .compact
            )

            Text(group.name)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                viewModel.removeCompanionGroup(group)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
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
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    var embedded: Bool = false
    @StateObject private var locationProvider = WhenInUseLocationProvider()

    var body: some View {
        Group {
            if embedded {
                compactLocationContent
            } else {
                fullLocationList
            }
        }
        .onAppear { locationProvider.requestIfAuthorized() }
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

    private var compactLocationContent: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            SplickTextField(languageService.text(.feedCreateLocationPlaceholder), text: $viewModel.location)
            if !viewModel.locationGpsAvailable {
                Button {
                    locationProvider.request()
                } label: {
                    Text(languageService.text(.feedCreateLocationEnableGps))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
            if viewModel.isSearchingPlaces {
                SplickSpinner(size: .small)
            }
            if showsCustomPlaceRow {
                Button {
                    viewModel.useTypedLocation()
                } label: {
                    Text(languageService.format(.feedCreateLocationUseTyped, trimmedQuery))
                }
            }
            if trimmedQuery.count >= 2 {
                ForEach(Array(viewModel.searchPlaces.prefix(6).enumerated()), id: \.offset) { _, place in
                    placeButton(place)
                }
            } else {
                ForEach(Array(viewModel.nearbyPlaces.prefix(6).enumerated()), id: \.offset) { _, place in
                    placeButton(place)
                }
            }
        }
    }

    private var fullLocationList: some View {
        List {
            Section {
                SplickTextField(languageService.text(.feedCreateLocationPlaceholder), text: $viewModel.location)
                if !viewModel.locationGpsAvailable {
                    Button {
                        locationProvider.request()
                    } label: {
                        Text(languageService.text(.feedCreateLocationEnableGps))
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.primary)
                    }
                    .buttonStyle(.plain)
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(languageService.text(.commonDone)) {
                    dismiss()
                }
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

private struct BillShareActionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(SplickTheme.Typography.captionBold)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(SplickTheme.Colors.primary)
        .frame(maxWidth: .infinity, minHeight: ComposeMetrics.actionChipHeight)
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.primary.opacity(0.08))
        .clipShape(
            RoundedRectangle(cornerRadius: ComposeMetrics.fieldCornerRadius, style: .continuous)
        )
    }
}

private struct ComposeNearbyRadarButton: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var nearbyRadar: NearbyRadarSessionViewModel
    @State private var showNearbyRadar = false
    @State private var selectedIds: Set<UUID> = []
    let selectedCompanionIds: Set<UUID>
    let onAddCompanion: (UserSummary) -> Void
    let onRemoveCompanion: (UserSummary) -> Void

    init(
        nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol,
        profileDependencies: FriendUserProfileDependencies,
        languageService: LanguageService,
        selectedCompanionIds: Set<UUID>,
        onAddCompanion: @escaping (UserSummary) -> Void,
        onRemoveCompanion: @escaping (UserSummary) -> Void
    ) {
        _nearbyRadar = StateObject(
            wrappedValue: NearbyRadarSessionViewModel(
                nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                addFriendUseCase: profileDependencies.addFriendUseCase,
                acceptFriendRequestUseCase: profileDependencies.acceptFriendRequestUseCase,
                cancelFriendRequestUseCase: profileDependencies.cancelFriendRequestUseCase,
                fetchIncomingFriendRequestsUseCase: profileDependencies.fetchIncomingFriendRequestsUseCase,
                fetchOutgoingFriendRequestsUseCase: profileDependencies.fetchOutgoingFriendRequestsUseCase,
                languageService: languageService
            )
        )
        self.selectedCompanionIds = selectedCompanionIds
        self.onAddCompanion = onAddCompanion
        self.onRemoveCompanion = onRemoveCompanion
    }

    var body: some View {
        Button {
            selectedIds = selectedCompanionIds
            showNearbyRadar = true
            nearbyRadar.startRadarSession()
        } label: {
            BillShareActionChip(
                title: languageService.text(.feedCreateNearbyChip),
                systemImage: "dot.radiowaves.left.and.right"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(languageService.text(.friendsNearbyOpen))
        .fullScreenCover(isPresented: $showNearbyRadar, onDismiss: {
            nearbyRadar.stopRadarSession()
        }) {
            NearbyRadarSheet(
                permissionNeeded: nearbyRadar.nearbyPermissionNeeded,
                users: nearbyRadar.nearbyUsers,
                loading: nearbyRadar.nearbyLoading,
                locationDisabled: nearbyRadar.nearbyLocationDisabled,
                selectionMode: true,
                selectedUserIds: selectedIds,
                onClose: {
                    showNearbyRadar = false
                    nearbyRadar.stopRadarSession()
                },
                onRequestLocation: nearbyRadar.requestNearbyLocationAccess,
                onOpenUser: { _ in },
                actionForResult: nearbyRadar.actionForResult,
                onToggleSelection: { result in
                    if selectedIds.contains(result.user.id) {
                        selectedIds.remove(result.user.id)
                    } else {
                        selectedIds.insert(result.user.id)
                    }
                },
                onConfirmSelection: {
                    for result in nearbyRadar.nearbyUsers {
                        if selectedIds.contains(result.user.id) {
                            onAddCompanion(result.user)
                        } else if selectedCompanionIds.contains(result.user.id) {
                            onRemoveCompanion(result.user)
                        }
                    }
                    showNearbyRadar = false
                    nearbyRadar.stopRadarSession()
                }
            )
            .environmentObject(languageService)
        }
        .alert(
            languageService.text(.friendsNearbyTitle),
            isPresented: Binding(
                get: { nearbyRadar.alertMessage != nil },
                set: { if !$0 { nearbyRadar.alertMessage = nil } }
            )
        ) {
            Button(languageService.text(.commonOK), role: .cancel) {
                nearbyRadar.alertMessage = nil
            }
        } message: {
            Text(nearbyRadar.alertMessage ?? "")
        }
        .onDisappear {
            if showNearbyRadar {
                showNearbyRadar = false
                nearbyRadar.stopRadarSession()
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

    func requestIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            didFinishRequest = true
            coordinate = nil
        default:
            break
        }
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
