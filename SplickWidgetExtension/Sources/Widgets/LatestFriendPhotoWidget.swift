import WidgetKit
import SwiftUI
import SplickWidgetKit

struct LatestFriendPhotoEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetLatestFriendPhotoSnapshot?
    let imageURL: URL?
}

struct LatestFriendPhotoProvider: TimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> LatestFriendPhotoEntry {
        LatestFriendPhotoEntry(
            date: .now,
            snapshot: WidgetLatestFriendPhotoSnapshot(
                postId: UUID(),
                authorName: "Bạn bè",
                authorUsername: "friend",
                reactionCount: 5,
                createdAt: .now,
                cachedImageFilename: nil,
                remoteImageURL: nil
            ),
            imageURL: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LatestFriendPhotoEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestFriendPhotoEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 20, to: .now) ?? .now.addingTimeInterval(1200)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> LatestFriendPhotoEntry {
        let snapshot = cache.loadLatestFriendPhoto()
        let imageURL = snapshot.flatMap { cache.cachedImageURL(for: $0) }
        return LatestFriendPhotoEntry(date: .now, snapshot: snapshot, imageURL: imageURL)
    }
}

struct LatestFriendPhotoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LatestFriendPhotoEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var hasPhoto: Bool {
        guard let snapshot = entry.snapshot else { return false }
        return !snapshot.authorName.isEmpty
    }

    private var smallView: some View {
        ZStack {
            if hasPhoto, let imageURL = entry.imageURL, let uiImage = UIImage(contentsOfFile: imageURL.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                WidgetPlaceholderView(title: "Ảnh bạn bè", systemImage: "photo.on.rectangle.angled")
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            if let snapshot = entry.snapshot, hasPhoto {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer()
                    Text(snapshot.authorName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        Text(WidgetRelativeDateFormatter.shortString(from: snapshot.createdAt))
                        if snapshot.reactionCount > 0 {
                            Label("\(snapshot.reactionCount)", systemImage: "heart.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .clipped()
    }

    private var mediumView: some View {
        HStack(spacing: 0) {
            ZStack {
                if hasPhoto, let imageURL = entry.imageURL, let uiImage = UIImage(contentsOfFile: imageURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    WidgetPlaceholderView(title: "Ảnh mới", systemImage: "photo")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            if let snapshot = entry.snapshot, hasPhoto {
                VStack(alignment: .leading, spacing: 8) {
                    WidgetBrandHeader("Locket")
                    Text(snapshot.authorName)
                        .font(.title3.weight(.bold))
                        .lineLimit(2)
                    Text("@\(snapshot.authorUsername)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(WidgetRelativeDateFormatter.shortString(from: snapshot.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if snapshot.reactionCount > 0 {
                        Label("\(snapshot.reactionCount) reactions", systemImage: "heart.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetColors.error)
                    }
                }
                .padding()
                .frame(width: 150)
                .background(Color(.systemBackground))
            }
        }
    }
}

struct LatestFriendPhotoWidget: Widget {
    let kind = WidgetKind.latestFriendPhoto

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LatestFriendPhotoProvider()) { entry in
            LatestFriendPhotoWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Ảnh bạn bè")
        .description("Ảnh mới nhất từ bạn bè ngay trên màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
