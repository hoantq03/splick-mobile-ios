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

enum ComposeMenuAnchor: Hashable {
    case tags
    case location
}

struct ComposeMenuAnchorKey: PreferenceKey {
    static var defaultValue: [ComposeMenuAnchor: CGRect] = [:]

    static func reduce(value: inout [ComposeMenuAnchor: CGRect], nextValue: () -> [ComposeMenuAnchor: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct ComposeMenuAnchorReporter: View {
    let anchor: ComposeMenuAnchor

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ComposeMenuAnchorKey.self,
                value: [anchor: proxy.frame(in: .named(ComposeMenuSpace.name))]
            )
        }
    }
}

enum ComposeMenuSpace {
    static let name = "composeMenus"
}

func revealComposeSearch(_ proxy: ScrollViewProxy, _ id: ComposeSearchAnchor) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
        withAnimation(ComposeSearchExpandMotion.spring) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}

enum ComposeSearchExpandMotion {
    static let spring = Animation.spring(response: 0.44, dampingFraction: 0.66)
}

private struct ComposeSearchHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ComposeBottomBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Grows downward from the search field's bottom edge. `move(edge:)` inside a
/// ScrollView travels from the scroll view's top instead of the field.
private struct ComposeSearchResultsExpand<Content: View>: View {
    let isExpanded: Bool
    let content: Content

    init(isExpanded: Bool, @ViewBuilder content: () -> Content) {
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: ComposeSearchHeightKey.self, value: proxy.size.height)
                }
            }
            .modifier(ComposeSearchHeightClip(isExpanded: isExpanded))
            .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct ComposeSearchHeightClip: ViewModifier {
    let isExpanded: Bool
    @State private var measuredHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .top)
            .frame(height: isExpanded ? measuredHeight : 0, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .top)
            .clipped()
            .opacity(isExpanded && measuredHeight > 1 ? 1 : 0)
            .allowsHitTesting(isExpanded)
            .accessibilityHidden(!isExpanded)
            .onPreferenceChange(ComposeSearchHeightKey.self) { newHeight in
                updateMeasuredHeight(newHeight)
            }
    }

    private func updateMeasuredHeight(_ newHeight: CGFloat) {
        guard newHeight.isFinite, newHeight > 1 else { return }
        guard abs(newHeight - measuredHeight) > 0.5 else { return }

        if measuredHeight == 0 {
            if isExpanded {
                withAnimation(ComposeSearchExpandMotion.spring) {
                    measuredHeight = newHeight
                }
            } else {
                measuredHeight = newHeight
            }
            return
        }

        if isExpanded {
            withAnimation(ComposeSearchExpandMotion.spring) {
                measuredHeight = newHeight
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                measuredHeight = newHeight
            }
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
    @State private var showCompanionsMenu = false
    @State private var showAudienceMenu = false
    @State private var showLocationMenu = false
    @State private var composeBottomBarHeight: CGFloat = 56
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
        .coordinateSpace(name: ComposeMenuSpace.name)
        .background(SplickTheme.Colors.background)
        .overlay(alignment: .bottomLeading) {
            if showAudienceMenu {
                composeBottomFloatingMenu {
                    ComposeAudienceMenuPopup(viewModel: viewModel) {
                        withAnimation(ComposeSearchExpandMotion.spring) {
                            showAudienceMenu = false
                        }
                    }
                }
            }
        }
        .overlayPreferenceValue(ComposeMenuAnchorKey.self) { frames in
            composeAnchoredMenus(frames)
        }
        .animation(ComposeSearchExpandMotion.spring, value: showAudienceMenu)
        .animation(ComposeSearchExpandMotion.spring, value: showCompanionsMenu)
        .animation(ComposeSearchExpandMotion.spring, value: showLocationMenu)
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
        if viewModel.selectedMediaItems.isEmpty {
            if viewModel.canAddMoreMedia {
                addMediaEmptyButton
                    .padding(.horizontal, SplickTheme.Spacing.md)
            }
        } else {
            let cardWidth = ComposeMetrics.mediaCardWidth
            let cardHeight = ComposeMetrics.mediaCardHeight
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ComposeMetrics.mediaCardSpacing) {
                        ForEach(viewModel.selectedMediaItems) { item in
                            composeMediaCard(item: item, width: cardWidth, height: cardHeight)
                        }
                    }
                    .padding(.leading, SplickTheme.Spacing.md)
                    .padding(.trailing, SplickTheme.Spacing.sm)
                }
                .overlay(alignment: .bottomLeading) {
                    if viewModel.canAddMoreMedia {
                        addMediaOverlayChip
                            .padding(.leading, SplickTheme.Spacing.md + SplickTheme.Spacing.sm)
                            .padding(.bottom, SplickTheme.Spacing.sm)
                    }
                }

                Text(languageService.text(.feedCreateMediaLimit))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .padding(.horizontal, SplickTheme.Spacing.md)
            }
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

    private var addMediaEmptyButton: some View {
        addMediaMenu {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text(languageService.text(.feedCreateAddMedia))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(SplickTheme.Colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
        }
        .accessibilityLabel(languageService.text(.feedCreateAddMedia))
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
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
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
        showBillSplitScreen
    }

    private var composeActionPills: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.xs) {
                    ComposeOptionPill(
                        title: languageService.text(.feedBillSplitTitle),
                        systemImage: "banknote.fill",
                        isActive: viewModel.hasBillSplitCounterparts || viewModel.parsedBillTotal != nil
                    ) {
                        openBillSplitScreen()
                    }
                    ComposeOptionPill(
                        title: languageService.text(.feedCreateTagFriends),
                        systemImage: "person.2.fill",
                        isActive: hasSelectedCompanions || showCompanionsMenu
                    ) {
                        toggleCompanionsMenu()
                    }
                    .background(ComposeMenuAnchorReporter(anchor: .tags))
                    ComposeOptionPill(
                        title: languageService.text(.feedCreateLocation),
                        systemImage: "mappin.and.ellipse",
                        isActive: hasSelectedLocation || showLocationMenu
                    ) {
                        toggleLocationMenu()
                    }
                    .background(ComposeMenuAnchorReporter(anchor: .location))
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
        VStack(alignment: .leading, spacing: 0) {
            Divider().opacity(0.55)
            HStack(spacing: SplickTheme.Spacing.sm) {
                KeyboardStickyTapControl(isEnabled: true, action: toggleAudienceMenu) {
                    audienceBarLabel
                }

                Spacer(minLength: SplickTheme.Spacing.sm)

                KeyboardStickyTapControl(isEnabled: true, action: submitPost) {
                    postBarLabel
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(SplickTheme.Colors.background)
            .accessibilityIdentifier(KeyboardDismissExempt.accessibilityIdentifier)
        }
        .background(SplickTheme.Colors.background)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ComposeBottomBarHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(ComposeBottomBarHeightKey.self) { height in
            guard height.isFinite, height > 1, abs(height - composeBottomBarHeight) > 0.5 else { return }
            composeBottomBarHeight = height
        }
        .zIndex(1)
    }

    private var audienceBarLabel: some View {
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
        .contentShape(Capsule())
    }

    private var postBarLabel: some View {
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
            .contentShape(Capsule())
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
            if !billRowSummaryText.isEmpty {
                composeSummaryChip(text: billRowSummaryText, tint: SplickTheme.Colors.success)
            }
            if hasSelectedCompanions {
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

    @ViewBuilder
    private func composeAnchoredMenus(_ frames: [ComposeMenuAnchor: CGRect]) -> some View {
        GeometryReader { proxy in
            if showCompanionsMenu || showLocationMenu {
                Color.clear
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(ComposeSearchExpandMotion.spring) {
                            showCompanionsMenu = false
                            showLocationMenu = false
                        }
                        hideKeyboard()
                        viewModel.setFriendSearchActive(false)
                    }
            }
            if showCompanionsMenu, let frame = frames[.tags] {
                anchoredMenu(frame: frame, containerWidth: proxy.size.width) {
                    ComposeCompanionsMenuPopup(
                        viewModel: viewModel,
                        onUserTap: openProfile,
                        nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                        profileDependencies: profileDependencies
                    )
                }
            }
            if showLocationMenu, let frame = frames[.location] {
                anchoredMenu(frame: frame, containerWidth: proxy.size.width) {
                    ComposeLocationMenuPopup(viewModel: viewModel) {
                        withAnimation(ComposeSearchExpandMotion.spring) {
                            showLocationMenu = false
                        }
                    }
                }
            }
        }
        .allowsHitTesting(showCompanionsMenu || showLocationMenu)
    }

    private func anchoredMenu<Content: View>(
        frame: CGRect,
        containerWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let inset = SplickTheme.Spacing.md
        let width = max(containerWidth - inset * 2, 0)
        let originX = width > 0 ? min(max((frame.midX - inset) / width, 0), 1) : 0
        return content()
            .frame(width: width, alignment: .top)
            .offset(x: inset, y: frame.maxY + 8)
            .transition(
                .scale(scale: 0.82, anchor: UnitPoint(x: originX, y: 0))
                    .combined(with: .opacity)
            )
    }

    @ViewBuilder
    private func composeBottomFloatingMenu<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
            Color.clear
                .frame(height: composeBottomBarHeight)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, SplickTheme.Spacing.md)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.82, anchor: .bottomLeading)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: 10)),
                removal: .opacity.combined(with: .offset(y: 6))
            )
        )
    }

    private func openBillSplitScreen() {
        hideKeyboard()
        viewModel.startCompanionDirectoryLoadIfNeeded()
        withAnimation(ComposeSearchExpandMotion.spring) {
            showCompanionsMenu = false
            showAudienceMenu = false
            showLocationMenu = false
        }
        showBillSplitScreen = true
    }

    private func toggleCompanionsMenu() {
        viewModel.startCompanionDirectoryLoadIfNeeded()
        withAnimation(ComposeSearchExpandMotion.spring) {
            showAudienceMenu = false
            showLocationMenu = false
            showCompanionsMenu.toggle()
        }
        if showCompanionsMenu {
            viewModel.setFriendSearchActive(true)
        } else {
            hideKeyboard()
            viewModel.setFriendSearchActive(false)
        }
    }

    private func toggleLocationMenu() {
        withAnimation(ComposeSearchExpandMotion.spring) {
            showAudienceMenu = false
            showCompanionsMenu = false
            showLocationMenu.toggle()
        }
        if !showLocationMenu {
            hideKeyboard()
        }
    }

    private func toggleAudienceMenu() {
        hideKeyboard()
        withAnimation(ComposeSearchExpandMotion.spring) {
            showCompanionsMenu = false
            showLocationMenu = false
            showAudienceMenu.toggle()
        }
    }

    private var hasSelectedCompanions: Bool {
        !viewModel.selectedCompanions.isEmpty
            || !viewModel.selectedCompanionGroups.isEmpty
    }

    private var hasSelectedLocation: Bool {
        !viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasComposeOptionSummaries: Bool {
        (viewModel.hasBillSplitCounterparts || viewModel.parsedBillTotal != nil)
            || hasSelectedCompanions
            || hasSelectedLocation
    }

    private var companionsSummaryText: String {
        let phrase = companionsSummaryPhrase
        guard !phrase.isEmpty else {
            return languageService.text(.feedCreateMomentCompanionsHint)
        }
        return languageService.format(.feedCreateTagSummary, phrase)
    }

    private var companionsSummaryPhrase: String {
        let companionNames = viewModel.selectedCompanions.map(composeGivenName)

        if let groupName = viewModel.companionGroupDisplayName,
           !groupName.isEmpty {
            let otherCount = companionNames.count
            if otherCount == 0 {
                return groupName
            }
            return groupName + languageService.format(.feedCompanionsAndOthers, otherCount)
        }

        guard !companionNames.isEmpty else { return "" }

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
        let people = billSummaryPeoplePhrase
        if let total = viewModel.parsedBillTotal, total > 0 {
            let amount = VNDMoneyFormat.formatDisplay(total)
            if people.isEmpty {
                return languageService.format(.feedCreateBillSummaryAmount, amount)
            }
            return languageService.format(.feedCreateBillSummaryWithPeople, amount, people)
        }
        if people.isEmpty { return "" }
        return languageService.format(.feedCreateBillSummaryPeople, people)
    }

    private var billSummaryPeoplePhrase: String {
        let names = viewModel.billSplitParticipants
            .filter { !viewModel.isCurrentUser($0) }
            .map(composeGivenName)
            + viewModel.pendingGuests.map { composeGivenName($0.displayName, fallback: $0.email) }
        let uniqueNames = names.reduce(into: [String]()) { partial, name in
            guard !name.isEmpty, !partial.contains(name) else { return }
            partial.append(name)
        }
        guard !uniqueNames.isEmpty else { return "" }
        if uniqueNames.count == 1 { return uniqueNames[0] }
        let preview = uniqueNames.prefix(2).joined(separator: ", ")
        if uniqueNames.count == 2 { return preview }
        return preview + languageService.format(.feedCompanionsAndOthers, uniqueNames.count - 2)
    }

    private var locationSummaryText: String {
        let trimmed = viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? languageService.text(.feedCreateLocationHint) : trimmed
    }

    private func composeGivenName(_ user: UserSummary) -> String {
        composeGivenName(user.displayName, fallback: user.username)
    }

    private func composeGivenName(_ displayName: String, fallback: String) -> String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return fallback }
        return trimmedName.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? trimmedName
    }
}

struct ComposeOptionPill: View {
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

private struct ComposeBillSplitView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    let onUserTap: (UserSummary) -> Void
    @State private var revealedBillPartyIds: Set<UUID> = []
    @State private var displayedBillParticipants: [UserSummary] = []
    @State private var displayedBillGuests: [ComposePendingGuest] = []
    @State private var billPartyPresentIds: Set<UUID> = []
    @State private var billPartyDismissDelay: [UUID: Double] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                composerIdentity
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.top, SplickTheme.Spacing.sm)

                totalAmountField
                    .padding(.horizontal, SplickTheme.Spacing.md)

                splitModePills

                reminderRow
                    .padding(.horizontal, SplickTheme.Spacing.md)

                Text(languageService.text(.feedCreateBillWith))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .padding(.horizontal, SplickTheme.Spacing.md)

                billSplitDetailFields
                    .padding(.horizontal, SplickTheme.Spacing.md)

                ComposeCompanionsEditorView(
                    viewModel: viewModel,
                    onUserTap: onUserTap,
                    nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                    profileDependencies: profileDependencies,
                    embedded: true,
                    billMode: true
                )
                .padding(.horizontal, SplickTheme.Spacing.md)
            }
            .padding(.bottom, SplickTheme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(SplickTheme.Colors.background)
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

    private var splitModePills: some View {
        HStack(spacing: 0) {
            ForEach(Array(ComposeBillSplitMode.allCases.enumerated()), id: \.element.id) { index, mode in
                if index > 0 {
                    Rectangle()
                        .fill(SplickTheme.Colors.divider.opacity(0.7))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }

                Button {
                    viewModel.splitMode = mode
                } label: {
                    Text(languageService.text(mode.titleKey))
                        .font(SplickTheme.Typography.callout)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(
                            viewModel.splitMode == mode
                                ? SplickTheme.Colors.brandBlue
                                : SplickTheme.Colors.textPrimary
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 6)
                        .background(
                            viewModel.splitMode == mode
                                ? SplickTheme.Colors.brandBlue.opacity(0.12)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.splitMode == mode ? AccessibilityTraits.isSelected : [])
            }
        }
        .frame(minHeight: ComposeMetrics.actionChipHeight)
        .background(SplickTheme.Colors.secondaryBackground)
        .overlay {
            Capsule()
                .strokeBorder(SplickTheme.Colors.divider.opacity(0.7), lineWidth: 1)
        }
        .clipShape(Capsule())
        .padding(.horizontal, SplickTheme.Spacing.md)
        .animation(.easeInOut(duration: 0.16), value: viewModel.splitMode)
    }

    private var reminderRow: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "bell.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(languageService.text(.feedCreateAutoReminder))
                .font(SplickTheme.Typography.callout)
                .fontWeight(.semibold)
                .lineLimit(2)
            Spacer(minLength: SplickTheme.Spacing.sm)
            Toggle("", isOn: $viewModel.autoReminderEnabled)
                .labelsHidden()
                .tint(SplickTheme.Colors.brandBlue)
                .scaleEffect(0.82)
                .frame(width: 42, height: 26)
        }
        .foregroundStyle(SplickTheme.Colors.textPrimary)
        .padding(.horizontal, 12)
        .frame(minHeight: ComposeMetrics.actionChipHeight)
        .background(SplickTheme.Colors.secondaryBackground)
        .overlay {
            Capsule()
                .strokeBorder(SplickTheme.Colors.divider.opacity(0.7), lineWidth: 1)
        }
        .clipShape(Capsule())
    }

    private var totalAmountField: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: SplickTheme.Spacing.sm) {
                LiveVNDMoneyTextField(
                    text: $viewModel.billTotalText,
                    font: .systemFont(ofSize: 20, weight: .regular),
                    textColor: UIColor(SplickTheme.Colors.textPrimary),
                    placeholder: languageService.text(.feedCreateTotalAmount)
                )

                Text(languageService.text(.feedCreateCurrencySymbol))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            if let error = viewModel.billTotalAmountError {
                Text(error)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.error)
            }
        }
    }

    @ViewBuilder
    private var billSplitDetailFields: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
        switch viewModel.splitMode {
        case .equal:
            let amountLabel = viewModel.equalShareAmount.map { VNDMoneyFormat.formatDisplay($0) }
                ?? ("— " + languageService.text(.feedCreateCurrencySymbol))
            ForEach(billSplitListParticipants) { user in
                participantAmountPreviewRow(for: user, amountLabel: amountLabel)
                    .modifier(billSplitPartyMotion(for: user.id))
            }
            ForEach(billSplitListGuests) { guest in
                guestAmountPreviewRow(guest, amountLabel: amountLabel)
                    .modifier(billSplitPartyMotion(for: guest.id))
            }

        case .percentage:
            ForEach(billSplitListParticipants) { user in
                percentageRow(for: user)
                    .modifier(billSplitPartyMotion(for: user.id))
            }
            ForEach(billSplitListGuests) { guest in
                percentageRow(guestId: guest.id, identity: guestIdentityView(guest))
                    .modifier(billSplitPartyMotion(for: guest.id))
            }

        case .exact:
            ForEach(billSplitListParticipants) { user in
                exactAmountRow(for: user)
                    .modifier(billSplitPartyMotion(for: user.id))
            }
            ForEach(billSplitListGuests) { guest in
                exactAmountRow(guestId: guest.id, identity: guestIdentityView(guest))
                    .modifier(billSplitPartyMotion(for: guest.id))
            }
        }
        }
        .animation(
            .spring(response: 0.42, dampingFraction: 0.68),
            value: displayedBillParticipants.map(\.id) + displayedBillGuests.map(\.id)
        )
        .onAppear { syncBillSplitDisplayedParties() }
        .onValueChange(of: viewModel.billSplitPartyIds) { _ in
            syncBillSplitDisplayedParties()
        }
    }

    private func billSplitPartyMotion(for id: UUID) -> BillSplitRowAppear {
        BillSplitRowAppear(
            delay: billSplitAppearDelay(for: id),
            animate: billSplitShouldAppear(id),
            isPresent: displayedBillParticipants.isEmpty && displayedBillGuests.isEmpty
                ? true
                : billPartyPresentIds.contains(id),
            dismissDelay: billPartyDismissDelay[id] ?? 0
        )
    }

    private var billSplitListParticipants: [UserSummary] {
        displayedBillParticipants.isEmpty ? viewModel.billSplitParticipants : displayedBillParticipants
    }

    private var billSplitListGuests: [ComposePendingGuest] {
        displayedBillGuests.isEmpty ? viewModel.pendingGuests : displayedBillGuests
    }

    private func billSplitNewcomerIndex(for id: UUID) -> Int? {
        viewModel.billSplitPartyIds.filter { !revealedBillPartyIds.contains($0) }.firstIndex(of: id)
    }

    private func billSplitAppearDelay(for id: UUID) -> Double {
        Double(billSplitNewcomerIndex(for: id) ?? 0) * 0.07
    }

    private func billSplitShouldAppear(_ id: UUID) -> Bool {
        billSplitNewcomerIndex(for: id) != nil
    }

    private func commitRevealedBillPartyIds() {
        let ids = viewModel.billSplitPartyIds
        DispatchQueue.main.async {
            revealedBillPartyIds.formIntersection(Set(ids))
            revealedBillPartyIds.formUnion(ids)
        }
    }

    private func syncBillSplitDisplayedParties() {
        let liveParticipants = viewModel.billSplitParticipants
        let liveGuests = viewModel.pendingGuests
        let liveIds = Set(viewModel.billSplitPartyIds)

        if displayedBillParticipants.isEmpty && displayedBillGuests.isEmpty {
            displayedBillParticipants = liveParticipants
            displayedBillGuests = liveGuests
            billPartyPresentIds = liveIds
            commitRevealedBillPartyIds()
            return
        }

        let liveParticipantById = Dictionary(uniqueKeysWithValues: liveParticipants.map { ($0.id, $0) })
        let liveGuestById = Dictionary(uniqueKeysWithValues: liveGuests.map { ($0.id, $0) })
        var present = billPartyPresentIds
        var dismissDelay = billPartyDismissDelay
        var leaverIndex = 0
        var seen = Set<UUID>()
        var nextParticipants: [UserSummary] = []
        var nextGuests: [ComposePendingGuest] = []

        func markLeaving(_ id: UUID) {
            present.remove(id)
            dismissDelay[id] = Double(leaverIndex) * 0.07
            leaverIndex += 1
            scheduleBillPartyDismissal(id: id, delay: dismissDelay[id] ?? 0)
        }

        for user in displayedBillParticipants {
            seen.insert(user.id)
            if let live = liveParticipantById[user.id] {
                nextParticipants.append(live)
                present.insert(user.id)
            } else if present.contains(user.id) {
                nextParticipants.append(user)
                markLeaving(user.id)
            } else {
                nextParticipants.append(user)
            }
        }
        for guest in displayedBillGuests {
            seen.insert(guest.id)
            if let live = liveGuestById[guest.id] {
                nextGuests.append(live)
                present.insert(guest.id)
            } else if present.contains(guest.id) {
                nextGuests.append(guest)
                markLeaving(guest.id)
            } else {
                nextGuests.append(guest)
            }
        }
        for user in liveParticipants where !seen.contains(user.id) {
            nextParticipants.append(user)
            present.insert(user.id)
            seen.insert(user.id)
        }
        for guest in liveGuests where !seen.contains(guest.id) {
            nextGuests.append(guest)
            present.insert(guest.id)
            seen.insert(guest.id)
        }

        displayedBillParticipants = nextParticipants
        displayedBillGuests = nextGuests
        billPartyPresentIds = present
        billPartyDismissDelay = dismissDelay
        commitRevealedBillPartyIds()
    }

    private func scheduleBillPartyDismissal(id: UUID, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.42) {
            if billPartyPresentIds.contains(id) { return }
            displayedBillParticipants.removeAll { $0.id == id }
            displayedBillGuests.removeAll { $0.id == id }
            billPartyDismissDelay[id] = nil
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

            billRemoveControl(isEnabled: !viewModel.isCurrentUser(user)) {
                viewModel.removeBillSplitParticipant(user)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule())
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

            billRemoveControl {
                viewModel.removePendingGuest(guest)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule())
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
                .lineLimit(1)

            billPartyRemoveButton(partyId: guestId)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule())
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
                .frame(minWidth: 88)

                Text(languageService.text(.feedCreateCurrencySymbol))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }

            billPartyRemoveButton(partyId: guestId)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func billPartyRemoveButton(partyId: UUID) -> some View {
        if viewModel.isCurrentUser(id: partyId) {
            billRemoveControl(isEnabled: false, action: {})
        } else if let user = viewModel.billSplitParticipants.first(where: { $0.id == partyId }) {
            billRemoveControl {
                viewModel.removeBillSplitParticipant(user)
            }
        } else if let guest = viewModel.pendingGuests.first(where: { $0.id == partyId }) {
            billRemoveControl {
                viewModel.removePendingGuest(guest)
            }
        } else {
            billRemoveControl(isEnabled: false, action: {})
        }
    }

    private func billRemoveControl(
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(isEnabled ? SplickTheme.Colors.textTertiary : .clear)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(width: 16, height: 16)
        .accessibilityHidden(!isEnabled)
        .accessibilityLabel(languageService.text(.commonClear))
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

struct ComposeCompanionsMenuPopup: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let onUserTap: (UserSummary) -> Void
    let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCreateMomentWith))
                .font(SplickTheme.Typography.callout)
                .fontWeight(.semibold)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.horizontal, 4)

            ComposeCompanionsEditorView(
                viewModel: viewModel,
                onUserTap: onUserTap,
                nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                profileDependencies: profileDependencies,
                embedded: true,
                billMode: false,
                autoExpandSearch: true
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 420, alignment: .top)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .strokeBorder(SplickTheme.Colors.divider.opacity(0.5), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
    }
}

struct ComposeCompanionsEditorView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    let onUserTap: (UserSummary) -> Void
    let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    let profileDependencies: FriendUserProfileDependencies?
    var embedded: Bool = false
    var billMode: Bool = false
    var autoExpandSearch: Bool = false
    var onSearchFocused: (() -> Void)? = nil
    @FocusState private var isFriendSearchFocused: Bool
    @State private var showAddGuestSheet = false
    @State private var isBillSearchExpanded = false

    private var isBillCompanionMode: Bool {
        billMode
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
                    if !billMode {
                        if !viewModel.selectedCompanionGroups.isEmpty {
                            ForEach(viewModel.selectedCompanionGroups) { group in
                                selectedCompanionGroupCard(group)
                            }
                        }

                        if !viewModel.selectedCompanions.isEmpty {
                            selectedCompanionsStrip
                        }
                    }

                    if isBillCompanionMode {
                        billShareAddActions
                        if !viewModel.pendingGuests.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                                    ForEach(viewModel.pendingGuests) { guest in
                                        selectedGuestTile(for: guest)
                                    }
                                }
                                .padding(.vertical, SplickTheme.Spacing.xxxs)
                            }
                        }
                    }

                    if let notice = viewModel.peoplePickerNotice {
                        Text(notice)
                            .font(SplickTheme.Typography.caption)
                            .foregroundStyle(SplickTheme.Colors.brandBlue)
                    }

                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(autoExpandSearch ? SplickTheme.Colors.background : SplickTheme.Colors.secondaryBackground)
                        .clipShape(Capsule())

                        ComposeSearchResultsExpand(isExpanded: showsFriendSearchResults) {
                            friendSearchResultsList
                                .frame(maxWidth: .infinity, maxHeight: ComposeMetrics.searchResultsMaxHeight, alignment: .top)
                                .background(autoExpandSearch ? Color.clear : SplickTheme.Colors.secondaryBackground)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: autoExpandSearch ? 0 : SplickTheme.CornerRadius.large,
                                        style: .continuous
                                    )
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(ComposeSearchAnchor.companions)
                    .animation(ComposeSearchExpandMotion.spring, value: showsFriendSearchResults)
        }
        .onAppear {
            viewModel.peoplePickerTarget = billMode ? .bill : .tags
            if autoExpandSearch {
                viewModel.startCompanionDirectoryLoadIfNeeded()
                viewModel.setFriendSearchActive(true)
                isFriendSearchFocused = true
            }
        }
    }

    private func handleFriendSearchFocus(_ focused: Bool, reveal: () -> Void) {
        withAnimation(ComposeSearchExpandMotion.spring) {
            viewModel.setFriendSearchActive(focused)
            if billMode, focused {
                isBillSearchExpanded = true
            }
        }
        if focused {
            reveal()
        }
    }

    private func addCompanionAndKeepSearch(_ friend: UserSummary) {
        viewModel.addCompanion(friend, to: billMode ? .bill : .tags)
        guard billMode || autoExpandSearch else {
            if viewModel.occupancyNotice(for: friend.id, target: .tags) == nil {
                isFriendSearchFocused = false
                hideKeyboard()
            }
            return
        }
        isBillSearchExpanded = true
    }

    @ViewBuilder
    private var billShareAddActions: some View {
        if let nearbyDiscoveryUseCase, let profileDependencies {
            BillShareAsymmetricPair(spacing: SplickTheme.Spacing.sm, leadingWeight: 2, trailingWeight: 3) {
                ComposeNearbyRadarButton(
                    nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                    profileDependencies: profileDependencies,
                    languageService: languageService,
                    selectedCompanionIds: viewModel.selectedBillCompanionIds.union(
                        viewModel.selectedBillCompanionGroupMemberIds
                    ),
                    occupiedUserIds: viewModel.taggedUserIds,
                    onAddCompanion: { user in
                        viewModel.addCompanion(user, to: .bill)
                    },
                    onRemoveCompanion: { user in
                        viewModel.removeBillSplitParticipant(user)
                    }
                )
                addGuestWithoutAppButton
            }
        } else {
            addGuestWithoutAppButton
        }
    }

    private var addGuestWithoutAppButton: some View {
        Button {
            showAddGuestSheet = true
        } label: {
            BillShareActionChip(
                title: languageService.text(.feedCreateGuestSection),
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
                            addCompanionAndKeepSearch(friend)
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
                                    if let occupancy = viewModel.occupancyNotice(for: friend.id) {
                                        Text(occupancy)
                                            .font(SplickTheme.Typography.caption)
                                            .foregroundStyle(SplickTheme.Colors.brandBlue)
                                    } else {
                                        Text("@\(friend.username)")
                                            .font(SplickTheme.Typography.caption)
                                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            addCompanionAndKeepSearch(friend)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
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
        .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: ComposeMetrics.searchResultsMaxHeight)
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
                    viewModel.selectCompanionGroup(group, to: billMode ? .bill : .tags)
                    if billMode {
                        isBillSearchExpanded = true
                    } else if viewModel.occupancyNotice(forGroupId: group.id, target: .tags) == nil {
                        isFriendSearchFocused = false
                        hideKeyboard()
                    }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(Capsule())
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
                if let occupancy = viewModel.occupancyNotice(forGroupId: group.id) {
                    Text(occupancy)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.brandBlue)
                        .lineLimit(1)
                } else {
                    Text(languageService.format(.friendsMemberCount, group.memberCount))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func companionShortName(_ user: UserSummary) -> String {
        let trimmedName = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return user.username }
        let shortName = trimmedName.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? trimmedName
        return shortName
    }
}

struct ComposeLocationMenuPopup: View {
    @EnvironmentObject private var languageService: LanguageService
    @ObservedObject var viewModel: CreatePostComposeViewModel
    var onPlacePicked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCreateLocation))
                .font(SplickTheme.Typography.callout)
                .fontWeight(.semibold)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .padding(.horizontal, 4)

            ComposeLocationEditorView(
                viewModel: viewModel,
                embedded: true,
                autoFocusSearch: true,
                onPlacePicked: onPlacePicked
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 420, alignment: .top)
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.large, style: .continuous)
                .strokeBorder(SplickTheme.Colors.divider.opacity(0.5), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
    }
}

private struct ComposeLocationEditorView: View {
    @EnvironmentObject private var languageService: LanguageService
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CreatePostComposeViewModel
    var embedded: Bool = false
    var autoFocusSearch: Bool = false
    var onPlacePicked: (() -> Void)? = nil
    @StateObject private var locationProvider = WhenInUseLocationProvider()
    @FocusState private var isLocationFocused: Bool

    var body: some View {
        Group {
            if embedded {
                compactLocationContent
            } else {
                fullLocationList
            }
        }
        .onAppear {
            locationProvider.requestIfAuthorized()
            if autoFocusSearch {
                isLocationFocused = true
            }
        }
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
                .focused($isLocationFocused)
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
                    .frame(maxWidth: .infinity)
            } else if trimmedQuery.count >= 2 {
                if !viewModel.searchPlaces.isEmpty {
                    if showsCustomPlaceRow {
                        Button {
                            viewModel.useTypedLocation()
                            onPlacePicked?()
                        } label: {
                            Text(languageService.format(.feedCreateLocationUseTyped, trimmedQuery))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(Array(viewModel.searchPlaces.prefix(6).enumerated()), id: \.offset) { _, place in
                        placeButton(place)
                    }
                } else {
                    Text(languageService.text(.feedCreateLocationNotFound))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
            } else if viewModel.nearbyPlaces.isEmpty {
                EmptyView()
            } else {
                ForEach(Array(viewModel.nearbyPlaces.prefix(6).enumerated()), id: \.offset) { _, place in
                    placeButton(place)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fullLocationList: some View {
        List {
            Section {
                SplickTextField(languageService.text(.feedCreateLocationPlaceholder), text: $viewModel.location)
                    .focused($isLocationFocused)
                    .onChange(of: isLocationFocused) { focused in
                        if focused && viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Task { await viewModel.locationSearchHistory?.refresh() }
                        }
                    }
                if isLocationFocused,
                   viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let history = viewModel.locationSearchHistory {
                    RecentSearchesSection(
                        items: history.items,
                        languageService: languageService,
                        onSelect: { item in
                            viewModel.location = item.query
                            viewModel.locationQueryDidChange()
                        },
                        onDelete: { history.delete($0) },
                        onClearAll: { history.clear() }
                    )
                }
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

            if trimmedQuery.count >= 2, viewModel.searchPlaces.isEmpty, !viewModel.isSearchingPlaces {
                Section {
                    Text(languageService.text(.feedCreateLocationNotFound))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
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
            onPlacePicked?()
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

private struct BillShareAsymmetricPair<Content: View>: View {
    var spacing: CGFloat
    var leadingWeight: CGFloat
    var trailingWeight: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        BillShareAsymmetricPairLayout(
            spacing: spacing,
            leadingWeight: leadingWeight,
            trailingWeight: trailingWeight
        ) {
            content
        }
        .frame(maxWidth: .infinity, minHeight: ComposeMetrics.actionChipHeight)
    }
}

private struct BillShareAsymmetricPairLayout: Layout {
    var spacing: CGFloat
    var leadingWeight: CGFloat
    var trailingWeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = max(
            ComposeMetrics.actionChipHeight,
            subviews.map { $0.sizeThatFits(proposal).height }.max() ?? 0
        )
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        if subviews.count == 1 {
            subviews[0].place(
                at: bounds.origin,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
            return
        }
        let totalWeight = leadingWeight + trailingWeight
        let innerWidth = max(bounds.width - spacing, 0)
        let leadingWidth = innerWidth * (leadingWeight / totalWeight)
        let trailingWidth = innerWidth - leadingWidth
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: leadingWidth, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + leadingWidth + spacing, y: bounds.minY),
            proposal: ProposedViewSize(width: trailingWidth, height: bounds.height)
        )
    }
}

private struct BillShareActionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(SplickTheme.Typography.callout)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(SplickTheme.Colors.textPrimary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: ComposeMetrics.actionChipHeight)
        .background(SplickTheme.Colors.secondaryBackground)
        .overlay {
            Capsule()
                .strokeBorder(SplickTheme.Colors.divider.opacity(0.7), lineWidth: 1)
        }
        .clipShape(Capsule())
    }
}

private struct ComposeNearbyRadarButton: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var nearbyRadar: NearbyRadarSessionViewModel
    @State private var showNearbyRadar = false
    @State private var selectedIds: Set<UUID> = []
    let selectedCompanionIds: Set<UUID>
    let occupiedUserIds: Set<UUID>
    let onAddCompanion: (UserSummary) -> Void
    let onRemoveCompanion: (UserSummary) -> Void

    init(
        nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol,
        profileDependencies: FriendUserProfileDependencies,
        languageService: LanguageService,
        selectedCompanionIds: Set<UUID>,
        occupiedUserIds: Set<UUID> = [],
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
        self.occupiedUserIds = occupiedUserIds
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
                    if occupiedUserIds.contains(result.user.id) {
                        onAddCompanion(result.user)
                        return
                    }
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

private struct BillSplitRowAppear: ViewModifier {
    let isPresent: Bool
    let dismissDelay: Double
    @State private var appearDelay: Double
    @State private var shouldAnimate: Bool
    @State private var appeared = false
    @State private var started = false

    init(delay: Double, animate: Bool, isPresent: Bool, dismissDelay: Double) {
        self.isPresent = isPresent
        self.dismissDelay = dismissDelay
        _appearDelay = State(initialValue: delay)
        _shouldAnimate = State(initialValue: animate)
    }

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.72, anchor: .center)
            .offset(y: appeared ? 0 : 10)
            .onAppear { startIfNeeded() }
            .onValueChange(of: isPresent) { present in
                guard started else { return }
                applyPresence(present, delay: present ? 0 : dismissDelay)
            }
    }

    private func startIfNeeded() {
        guard !started else { return }
        started = true
        if !isPresent {
            appeared = false
            return
        }
        if !shouldAnimate {
            appeared = true
            return
        }
        applyPresence(true, delay: appearDelay)
    }

    private func applyPresence(_ present: Bool, delay: Double) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.52).delay(delay)) {
            appeared = present
        }
    }
}
