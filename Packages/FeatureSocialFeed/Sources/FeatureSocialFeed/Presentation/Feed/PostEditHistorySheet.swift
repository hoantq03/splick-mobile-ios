import SwiftUI
import DesignSystem
import Localization
import SplickDomain

struct PostEditHistorySheet: View {
    @EnvironmentObject private var languageService: LanguageService
    let postId: UUID
    let load: () async throws -> [PostEditRevision]
    @State private var revisions: [PostEditRevision] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .padding()
                } else if revisions.isEmpty {
                    Text(languageService.text(.feedPostEditHistoryEmpty))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                        .padding()
                } else {
                    List(revisions) { revision in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(revision.editedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                            if let caption = revision.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(.body)
                            }
                            historyMedia(revision.mediaItems)
                        }
                        .padding(.vertical, 6)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(languageService.text(.feedPostEditHistory))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonDone)) { dismiss() }
                }
            }
            .task { await loadHistory() }
        }
    }

    private func historyMedia(_ items: [PostMediaItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    AsyncImage(url: item.thumbnailURL ?? item.mediaURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Color.gray.opacity(0.15)
                        }
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .bottomTrailing) {
                        if item.mediaType == .video {
                            Image(systemName: "play.fill")
                                .font(.caption2)
                                .padding(4)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private func loadHistory() async {
        isLoading = true
        do {
            revisions = try await load()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
