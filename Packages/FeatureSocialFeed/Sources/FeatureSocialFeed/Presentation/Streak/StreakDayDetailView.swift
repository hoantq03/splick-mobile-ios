import SwiftUI
import DesignSystem
import Localization
import SplickDomain

/// Sheet with a horizontal peek-carousel of the day's photos.
/// Tapping a photo opens full post detail via `onPhotoTap`.
struct StreakDayDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageService: LanguageService

    let day: StreakDay
    let photos: [AlbumPhoto]
    let isLoading: Bool
    let onPhotoTap: (AlbumPhoto) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                SplickTheme.Colors.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if photos.isEmpty {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: languageService.text(.feedStreakEmptyDay),
                        message: dayTitle
                    )
                } else {
                    carouselContent
                }
            }
            .navigationTitle(dayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var carouselContent: some View {
        if #available(iOS 17.0, *) {
            StreakDayModernCarousel(photos: photos, onPhotoTap: onPhotoTap)
        } else {
            StreakDayLegacyCarousel(photos: photos, onPhotoTap: onPhotoTap)
        }
    }

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: day.date)
    }
}

// MARK: - Modern carousel (iOS 17+)

@available(iOS 17.0, *)
private struct StreakDayModernCarousel: View {
    let photos: [AlbumPhoto]
    let onPhotoTap: (AlbumPhoto) -> Void

    private let peekScale: CGFloat = 0.88
    private let peekOpacity: CGFloat = 0.5
    private let cardWidthRatio: CGFloat = 0.76

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * cardWidthRatio
            let sideInset = (geometry.size.width - cardWidth) / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    ForEach(photos) { photo in
                        StreakDayCarouselCard(
                            photo: photo,
                            width: cardWidth,
                            onTap: { onPhotoTap(photo) }
                        )
                        .scrollTransition(.animated(.spring(response: 0.35, dampingFraction: 0.82))) { content, phase in
                            let distance = abs(phase.value)
                            return content
                                .scaleEffect(1 - distance * (1 - peekScale))
                                .opacity(1 - distance * (1 - peekOpacity))
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sideInset)
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Legacy carousel (iOS 16)

private struct StreakDayLegacyCarousel: View {
    let photos: [AlbumPhoto]
    let onPhotoTap: (AlbumPhoto) -> Void

    @State private var currentIndex = 0

    private let peekScale: CGFloat = 0.88
    private let peekOpacity: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.76

            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    StreakDayCarouselCard(
                        photo: photo,
                        width: cardWidth,
                        onTap: { onPhotoTap(photo) }
                    )
                    .scaleEffect(index == currentIndex ? 1 : peekScale)
                    .opacity(index == currentIndex ? 1 : peekOpacity)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: currentIndex)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Carousel card

private struct StreakDayCarouselCard: View {
    @EnvironmentObject private var languageService: LanguageService

    let photo: AlbumPhoto
    let width: CGFloat
    let onTap: () -> Void

    private let cornerRadius: CGFloat = 20
    private var imageHeight: CGFloat { width * 4 / 3 }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                photoImage
                photoMeta
            }
            .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    private var photoImage: some View {
        GridThumbnailImage(url: photo.thumbnailURL ?? photo.mediaURL, thumbnailWidth: 900) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(SplickTheme.Colors.secondaryBackground)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
        }
        .frame(width: width, height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(SplickTheme.Colors.divider.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var photoMeta: some View {
        let caption = photo.caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = photo.checkInPlace?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasCaption = !(caption ?? "").isEmpty
        let hasCompanions = !photo.companions.isEmpty
        let hasPlace = !(place ?? "").isEmpty

        if hasCaption || hasCompanions || hasPlace {
            VStack(alignment: .leading, spacing: 6) {
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if hasCompanions {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        CompanionsSummaryText(
                            companions: photo.companions,
                            groupName: nil,
                            currentUserId: nil
                        )
                    }
                }

                if let place, !place.isEmpty {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        Text(languageService.format(.feedCheckInAt, place))
                            .font(.system(size: 11))
                            .foregroundStyle(SplickTheme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
