import SwiftUI
import PhotosUI
import UIKit
import DesignSystem
import Localization
import SplickDomain

@MainActor
final class EditPostComposeViewModel: ObservableObject {
    @Published var caption: String
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
        self.caption = post.caption ?? ""
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
        guard items.count < 8 else { return }
        items.append(
            DraftMedia(
                id: UUID(),
                imageData: data,
                mimeType: "image/jpeg",
                mediaType: .image
            )
        )
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func save() async -> Post? {
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
                    mediaItems: media
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
    @State private var pickerItems: [PhotosPickerItem] = []
    let onSaved: (Post) -> Void
    let onCancel: () -> Void

    init(
        post: Post,
        updatePost: @escaping (UpdatePostInput) async throws -> Post,
        onSaved: @escaping (Post) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: EditPostComposeViewModel(post: post, updatePost: updatePost))
        self.onSaved = onSaved
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    mediaStrip
                    TextField(languageService.text(.feedCreateCaptionPlaceholder), text: $viewModel.caption, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(12)
                        .background(SplickTheme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle(languageService.text(.feedPostEdit))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button(languageService.text(.commonSave)) {
                            Task {
                                if let post = await viewModel.save() {
                                    onSaved(post)
                                }
                            }
                        }
                        .disabled(viewModel.items.isEmpty)
                    }
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
                if viewModel.items.count < 8 {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 8 - viewModel.items.count,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "plus")
                            .frame(width: 96, height: 96)
                            .background(SplickTheme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .onChange(of: pickerItems) { _, newItems in
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
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run { viewModel.addImageData(data) }
            }
        }
        await MainActor.run { pickerItems = [] }
    }
}

private struct IdentifiedError: Identifiable {
    let message: String
    var id: String { message }
}
