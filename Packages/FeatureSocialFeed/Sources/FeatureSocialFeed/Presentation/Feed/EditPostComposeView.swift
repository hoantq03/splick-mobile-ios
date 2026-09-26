import SwiftUI
import PhotosUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers
import Common
import DesignSystem
import Localization
import Networking
import SplickDomain
import FeatureFriends

@MainActor
final class EditPostComposeViewModel: ObservableObject {
    @Published var items: [DraftMedia]
    @Published var isSaving = false
    @Published var errorMessage: String?

    let post: Post
    private let updatePost: (UpdatePostInput) async throws -> Post

    struct DraftMedia: Identifiable {
        let id: UUID
        var existing: PostMediaItem?
        var imageData: Data?
        var mimeType: String
        var mediaType: PostMediaType
        var durationSeconds: Int?
        var previewURL: URL?
    }

    init(post: Post, updatePost: @escaping (UpdatePostInput) async throws -> Post) {
        self.post = post
        self.updatePost = updatePost
        self.items = post.displayMediaItems.map { item in
            DraftMedia(
                id: item.id,
                existing: item,
                mimeType: item.mediaType == .video ? "video/mp4" : "image/jpeg",
                mediaType: item.mediaType,
                durationSeconds: item.durationSeconds,
                previewURL: item.thumbnailURL ?? item.mediaURL
            )
        }
    }

    func addImageData(_ data: Data) {
        guard items.count < 10 else { return }
        items.append(
            DraftMedia(
                id: UUID(),
                imageData: data,
                mimeType: "image/jpeg",
                mediaType: .image
            )
        )
    }

    func addVideo(data: Data, durationSeconds: Int?) {
        guard items.count < 10 else { return }
        items.append(
            DraftMedia(
                id: UUID(),
                imageData: data,
                mimeType: "video/mp4",
                mediaType: .video,
                durationSeconds: max(durationSeconds ?? 1, 1)
            )
        )
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func save(caption: String, audience: PostAudience, companionIds: [UUID]) async -> Post? {
        guard !items.isEmpty else { return nil }
        isSaving = true
        defer { isSaving = false }
        do {
            let media: [UpdatePostMediaItem] = items.map { item in
                if let existing = item.existing, item.imageData == nil {
                    return .existing(existing)
                }
                return .uploaded(
                    data: item.imageData ?? Data(),
                    mimeType: item.mimeType,
                    mediaType: item.mediaType,
                    videoDurationSeconds: item.durationSeconds
                )
            }
            return try await updatePost(
                UpdatePostInput(
                    postId: post.id,
                    caption: caption.isEmpty ? nil : caption,
                    mediaItems: media,
                    audience: audience,
                    companionIds: companionIds
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

struct EditPostComposeView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: EditPostComposeViewModel
    @StateObject private var composeViewModel: CreatePostComposeViewModel
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCompanionsMenu = false
    @State private var showAudienceMenu = false
    let profileDependencies: FriendUserProfileDependencies?
    let nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol?
    let onSaved: (Post) -> Void
    let onCancel: () -> Void

    init(
        post: Post,
        updatePost: @escaping (UpdatePostInput) async throws -> Post,
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        languageService: LanguageService,
        currentUser: UserSummary?,
        feedRepository: FeedRepositoryProtocol? = nil,
        searchHistoryRepository: SearchHistoryRepositoryProtocol? = nil,
        profileDependencies: FriendUserProfileDependencies? = nil,
        nearbyDiscoveryUseCase: NearbyDiscoveryUseCaseProtocol? = nil,
        onSaved: @escaping (Post) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EditPostComposeViewModel(post: post, updatePost: updatePost))
        _composeViewModel = StateObject(
            wrappedValue: CreatePostComposeViewModel(
                fetchFriendsUseCase: fetchFriendsUseCase,
                fetchMyGroupsUseCase: fetchMyGroupsUseCase,
                fetchGroupMembersUseCase: fetchGroupMembersUseCase,
                languageService: languageService,
                currentUser: currentUser,
                currentUserId: currentUser?.id,
                feedRepository: feedRepository,
                searchHistoryRepository: searchHistoryRepository,
                editingPost: post
            )
        )
        self.profileDependencies = profileDependencies
        self.nearbyDiscoveryUseCase = nearbyDiscoveryUseCase
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
                        editActionPills
                        TextField(
                            languageService.text(.feedCreateCaptionPlaceholder),
                            text: $composeViewModel.caption,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                        .padding(12)
                        .background(SplickTheme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, SplickTheme.Spacing.md)
                        mediaStrip
                            .padding(.horizontal, SplickTheme.Spacing.md)
                    }
                    .padding(.bottom, SplickTheme.Spacing.lg)
                }
                editBottomBar
            }
            .coordinateSpace(name: ComposeMenuSpace.name)
            .background(SplickTheme.Colors.background)
            .overlay(alignment: .bottomLeading) {
                if showAudienceMenu {
                    editBottomFloatingMenu {
                        ComposeAudienceMenuPopup(viewModel: composeViewModel) {
                            withAnimation(ComposeSearchExpandMotion.spring) {
                                showAudienceMenu = false
                            }
                        }
                    }
                }
            }
            .overlayPreferenceValue(ComposeMenuAnchorKey.self) { frames in
                GeometryReader { proxy in
                    if showCompanionsMenu {
                        Color.clear
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(ComposeSearchExpandMotion.spring) {
                                    showCompanionsMenu = false
                                }
                                composeViewModel.setFriendSearchActive(false)
                            }
                    }
                    if showCompanionsMenu, let frame = frames[.tags] {
                        let inset = SplickTheme.Spacing.md
                        let width = max(proxy.size.width - inset * 2, 0)
                        let originX = width > 0 ? min(max((frame.midX - inset) / width, 0), 1) : 0
                        ComposeCompanionsMenuPopup(
                            viewModel: composeViewModel,
                            onUserTap: { _ in },
                            nearbyDiscoveryUseCase: nearbyDiscoveryUseCase,
                            profileDependencies: profileDependencies
                        )
                        .frame(width: width, alignment: .top)
                        .offset(x: inset, y: frame.maxY + 8)
                        .transition(
                            .scale(scale: 0.82, anchor: UnitPoint(x: originX, y: 0))
                                .combined(with: .opacity)
                        )
                    }
                }
                .allowsHitTesting(showCompanionsMenu)
            }
            .animation(ComposeSearchExpandMotion.spring, value: showAudienceMenu)
            .animation(ComposeSearchExpandMotion.spring, value: showCompanionsMenu)
            .navigationTitle(languageService.text(.feedUploadEditPost))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel), action: onCancel)
                }
            }
            .alert(item: Binding(
                get: { viewModel.errorMessage.map { IdentifiedError(message: $0) } },
                set: { viewModel.errorMessage = $0?.message }
            )) { error in
                Alert(title: Text(error.message))
            }
        }
    }

    @ViewBuilder
    private func editBottomFloatingMenu<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
            Color.clear
                .frame(height: 56)
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

    private var hasSelectedCompanions: Bool {
        !composeViewModel.selectedCompanions.isEmpty || !composeViewModel.selectedCompanionGroups.isEmpty
    }

    private var editActionPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                ComposeOptionPill(
                    title: languageService.text(.feedCreateTagFriends),
                    systemImage: "person.2.fill",
                    isActive: hasSelectedCompanions || showCompanionsMenu
                ) {
                    composeViewModel.startCompanionDirectoryLoadIfNeeded()
                    withAnimation(ComposeSearchExpandMotion.spring) {
                        showAudienceMenu = false
                        showCompanionsMenu.toggle()
                    }
                    if showCompanionsMenu {
                        composeViewModel.setFriendSearchActive(true)
                    } else {
                        composeViewModel.setFriendSearchActive(false)
                    }
                }
                .background(ComposeMenuAnchorReporter(anchor: .tags))
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
        }
    }

    private var editBottomBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.55)
            HStack(spacing: SplickTheme.Spacing.sm) {
                KeyboardStickyTapControl(isEnabled: true, action: {
                    withAnimation(ComposeSearchExpandMotion.spring) {
                        showCompanionsMenu = false
                        showAudienceMenu.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(composeViewModel.audienceSummaryTitle)
                            .font(SplickTheme.Typography.callout)
                            .lineLimit(1)
                    }
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(Capsule())
                }
                Spacer()
                if viewModel.isSaving {
                    SplickSpinner()
                } else {
                    KeyboardStickyTapControl(isEnabled: !viewModel.items.isEmpty, action: save) {
                        Text(languageService.text(.commonSave))
                            .font(SplickTheme.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.items.isEmpty
                                    ? SplickTheme.Colors.brandBlue.opacity(0.35)
                                    : SplickTheme.Colors.brandBlue
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, SplickTheme.Spacing.md)
            .padding(.vertical, 10)
        }
    }

    private func save() {
        Task {
            if let post = await viewModel.save(
                caption: composeViewModel.caption,
                audience: composeViewModel.currentAudience,
                companionIds: composeViewModel.companionUsersForSubmit.map(\.id)
            ) {
                onSaved(post)
            }
        }
    }

    private var mediaStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.items) { item in
                    ZStack(alignment: .topTrailing) {
                        mediaPreview(item)
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Button {
                            viewModel.removeItem(id: item.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
                if viewModel.items.count < 10 {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10 - viewModel.items.count,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "plus")
                            .frame(width: 96, height: 96)
                            .background(SplickTheme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: pickerItems) { newItems in
                        Task { await loadPickerItems(newItems) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaPreview(_ item: EditPostComposeViewModel.DraftMedia) -> some View {
        if let data = item.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else if let url = item.previewURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: Color.gray.opacity(0.2)
                }
            }
        } else {
            Color.gray.opacity(0.2)
        }
    }

    private func loadPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                if let movie = try? await item.loadTransferable(type: EditPostMovie.self) {
                    await MainActor.run {
                        viewModel.addVideo(data: movie.data, durationSeconds: movie.durationSeconds)
                    }
                }
                continue
            }
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { viewModel.addImageData(data) }
            }
        }
        await MainActor.run { pickerItems = [] }
    }
}

private struct EditPostMovie: Transferable {
    let data: Data
    let durationSeconds: Int?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            try movie.data.write(to: url)
            return SentTransferredFile(url)
        } importing: { received in
            let data = try Data(contentsOf: received.file)
            let asset = AVURLAsset(url: received.file)
            let seconds = Int(round(CMTimeGetSeconds(asset.duration)))
            return EditPostMovie(data: data, durationSeconds: seconds > 0 ? seconds : 1)
        }
    }
}

private struct IdentifiedError: Identifiable {
    let message: String
    var id: String { message }
}
