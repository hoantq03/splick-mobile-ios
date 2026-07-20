import DesignSystem
import Localization
import Photos
import SwiftUI
import UIKit

/// In-app photo grid with multi-select; user confirms with the bottom bar or toolbar checkmark.
public struct MultiPhotoLibraryPickerView: View {
    @EnvironmentObject private var languageService: LanguageService
    public let maxSelectionCount: Int
    public let onConfirm: ([UIImage]) -> Void
    public let onCancel: () -> Void

    @StateObject private var viewModel: MultiPhotoLibraryPickerViewModel

    public init(
        maxSelectionCount: Int = 5,
        onConfirm: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.maxSelectionCount = max(1, maxSelectionCount)
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _viewModel = StateObject(
            wrappedValue: MultiPhotoLibraryPickerViewModel(limit: max(1, maxSelectionCount))
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: 0x0A0A0A).ignoresSafeArea()

                Group {
                    switch viewModel.accessState {
                    case .loading:
                        loadingView
                    case .denied:
                        permissionDeniedView
                    case .ready:
                        if viewModel.assets.isEmpty {
                            emptyLibraryView
                        } else {
                            photoGrid
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: 0x0A0A0A), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel), action: onCancel)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text(languageService.text(.mediaLibraryTitle))
                        .font(SplickTheme.Typography.headline)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    confirmToolbarButton
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomSelectionBar
            }
            .overlay {
                if viewModel.isImporting {
                    importingOverlay
                }
            }
        }
        .task {
            await viewModel.prepare()
        }
    }

    private var confirmToolbarButton: some View {
        Button {
            Task { await confirmSelection() }
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background {
                    Circle().fill(
                        viewModel.selectedAssetIDs.isEmpty
                            ? AnyShapeStyle(Color.white.opacity(0.18))
                            : AnyShapeStyle(SplickTheme.Colors.primaryGradient)
                    )
                }
        }
        .disabled(viewModel.selectedAssetIDs.isEmpty || viewModel.isImporting)
        .accessibilityLabel(languageService.text(.mediaConfirmSelectionA11y))
    }

    @ViewBuilder
    private var bottomSelectionBar: some View {
        if !viewModel.selectedAssetIDs.isEmpty {
            HStack(spacing: SplickTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(languageService.format(.mediaSelectedCount, viewModel.selectedAssetIDs.count, maxSelectionCount))
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(languageService.text(.mediaAddToPostHint))
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer(minLength: SplickTheme.Spacing.sm)

                Button {
                    Task { await confirmSelection() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text(languageService.text(.mediaAdd))
                            .font(SplickTheme.Typography.callout.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                    .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
                }
                .disabled(viewModel.isImporting)
            }
            .padding(.horizontal, PhotoGridLayout.screenHorizontalInset)
            .padding(.vertical, SplickTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 0.5)
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var loadingView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.1)
            Text(languageService.text(.mediaLibraryLoading))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var photoGrid: some View {
        GeometryReader { proxy in
            let horizontalInset = PhotoGridLayout.horizontalInset(for: proxy.safeAreaInsets)
            let cellSide = PhotoGridLayout.cellSide(
                containerWidth: proxy.size.width,
                horizontalInset: horizontalInset
            )

            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.isLimitedLibraryAccess {
                        limitedAccessBanner
                            .padding(.top, SplickTheme.Spacing.sm)
                            .padding(.bottom, SplickTheme.Spacing.xs)
                    }

                    LazyVGrid(
                        columns: PhotoGridLayout.gridColumns(cellSide: cellSide),
                        spacing: PhotoGridLayout.cellSpacing
                    ) {
                        ForEach(viewModel.assets, id: \.localIdentifier) { asset in
                            PhotoGridCell(
                                asset: asset,
                                cellSide: cellSide,
                                selectionIndex: viewModel.selectionIndex(for: asset.localIdentifier),
                                imageManager: viewModel.imageManager,
                                onToggleSelection: {
                                    viewModel.toggleSelection(for: asset.localIdentifier)
                                }
                            )
                        }
                    }
                    .padding(.top, PhotoGridLayout.cellSpacing)
                    .padding(.bottom, SplickTheme.Spacing.sm)
                }
                .padding(.horizontal, horizontalInset)
            }
        }
    }

    private var limitedAccessBanner: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "photo.badge.exclamationmark")
                .foregroundStyle(SplickTheme.Colors.warning)
            Text(languageService.text(.mediaLibraryLimitedAccess))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
        .padding(SplickTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var emptyLibraryView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.35))
            Text(languageService.text(.mediaLibraryEmptyTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)
            Text(languageService.text(.mediaLibraryEmptyMessage))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .padding(SplickTheme.Spacing.xl)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: SplickTheme.Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text(languageService.text(.mediaLibraryPermissionTitle))
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)
            Text(languageService.text(.mediaLibraryPermissionMessage))
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button(languageService.text(.notificationSettingsOpenSystemSettingsAction)) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(SplickTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.vertical, SplickTheme.Spacing.sm)
            .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
        }
        .padding(SplickTheme.Spacing.xl)
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: SplickTheme.Spacing.sm) {
                ProgressView()
                    .tint(.white)
                Text(languageService.text(.mediaLoadingSelected))
                    .font(SplickTheme.Typography.callout)
                    .foregroundStyle(.white)
            }
            .padding(SplickTheme.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @MainActor
    private func confirmSelection() async {
        guard let images = await viewModel.loadSelectedImages(), !images.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onConfirm(images)
    }
}

@MainActor
final class MultiPhotoLibraryPickerViewModel: ObservableObject {
    enum AccessState {
        case loading
        case denied
        case ready
    }

    @Published private(set) var accessState: AccessState = .loading
    @Published private(set) var assets: [PHAsset] = []
    @Published private(set) var selectedAssetIDs: [String] = []
    @Published private(set) var isImporting = false
    @Published private(set) var isLimitedLibraryAccess = false

    let imageManager = PHCachingImageManager()

    private let selectionLimit: Int
    private static let maxLoadedAssets = 800

    init(limit: Int) {
        selectionLimit = limit
        imageManager.allowsCachingHighQualityImages = false
    }

    func prepare() async {
        let status = await requestAuthorization()
        isLimitedLibraryAccess = status == .limited
        guard status == .authorized || status == .limited else {
            accessState = .denied
            return
        }
        assets = fetchImageAssets()
        accessState = .ready
    }

    func selectionIndex(for assetID: String) -> Int? {
        guard let index = selectedAssetIDs.firstIndex(of: assetID) else { return nil }
        return index + 1
    }

    func toggleSelection(for assetID: String) {
        if let index = selectedAssetIDs.firstIndex(of: assetID) {
            selectedAssetIDs.remove(at: index)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        guard selectedAssetIDs.count < selectionLimit else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        selectedAssetIDs.append(assetID)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func loadSelectedImages() async -> [UIImage]? {
        guard !selectedAssetIDs.isEmpty else { return nil }
        isImporting = true
        defer { isImporting = false }

        var images: [UIImage] = []
        for assetID in selectedAssetIDs {
            guard let asset = assets.first(where: { $0.localIdentifier == assetID }) else { continue }
            if let image = await loadFullSizeImage(for: asset) {
                images.append(image)
            }
        }
        return images.isEmpty ? nil : images
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func fetchImageAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAsset.fetchAssets(with: options)
        var fetched: [PHAsset] = []
        let count = min(result.count, Self.maxLoadedAssets)
        fetched.reserveCapacity(count)
        result.enumerateObjects { asset, index, stop in
            if index >= Self.maxLoadedAssets {
                stop.pointee = true
                return
            }
            fetched.append(asset)
        }
        return fetched
    }

    private func loadFullSizeImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: PhotoEditorImageProcessor.normalizeOrientation(image))
            }
        }
    }
}

/// Layout constants for a stable, edge-safe 3-column album grid.
private enum PhotoGridLayout {
    static let columnCount = 3
    static let cellSpacing = SplickTheme.Spacing.xs
    static let screenHorizontalInset = SplickTheme.Spacing.lg + SplickTheme.Spacing.xxs
    static let cornerRadius = SplickTheme.CornerRadius.small

    static func gridColumns(cellSide: CGFloat) -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(cellSide), spacing: cellSpacing),
            count: columnCount
        )
    }

    static var cellShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    static func horizontalInset(for safeInsets: EdgeInsets) -> CGFloat {
        max(screenHorizontalInset, safeInsets.leading + SplickTheme.Spacing.xs)
    }

    static func cellSide(containerWidth: CGFloat, horizontalInset: CGFloat) -> CGFloat {
        let contentWidth = containerWidth - horizontalInset * 2
        let totalSpacing = cellSpacing * CGFloat(columnCount - 1)
        let available = max(1, contentWidth - totalSpacing)
        return max(1, floor(available / CGFloat(columnCount)))
    }
}

private struct PhotoGridCell: View {
    let asset: PHAsset
    let cellSide: CGFloat
    let selectionIndex: Int?
    let imageManager: PHCachingImageManager
    let onToggleSelection: () -> Void

    @State private var thumbnail: UIImage?
    @State private var requestID: PHImageRequestID = PHInvalidImageRequestID

    private var isSelected: Bool { selectionIndex != nil }

    var body: some View {
        Button(action: onToggleSelection) {
            ZStack(alignment: .topTrailing) {
                thumbnailContent

                if isSelected {
                    Color.black.opacity(0.35)
                }

                selectionBadge
                    .padding(SplickTheme.Spacing.xs)
            }
            .frame(width: cellSide, height: cellSide)
            .clipShape(PhotoGridLayout.cellShape)
            .contentShape(PhotoGridLayout.cellShape)
        }
        .buttonStyle(.plain)
        // task(id:) cancels and restarts automatically when asset or cellSide changes
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
        .onDisappear {
            // Cancel in-flight request when cell scrolls out of view
            if requestID != PHInvalidImageRequestID {
                imageManager.cancelImageRequest(requestID)
                requestID = PHInvalidImageRequestID
            }
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnail {
            // Image is already square-cropped; scaledToFill + clipped is belt-and-suspenders.
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: cellSide, height: cellSide)
                .clipped()
        } else {
            ZStack {
                Color.white.opacity(0.06)
                ProgressView()
                    .tint(.white.opacity(0.5))
                    .scaleEffect(0.7)
            }
            .frame(width: cellSide, height: cellSide)
        }
    }

    private var selectionBadge: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
                .background(
                    Circle().fill(
                        isSelected
                            ? SplickTheme.Colors.primaryGradientStart
                            : Color.black.opacity(0.3)
                    )
                )
                .frame(width: 24, height: 24)

            if let selectionIndex {
                Text("\(selectionIndex)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .allowsHitTesting(false)
    }

    @MainActor
    private func loadThumbnail() async {
        thumbnail = nil

        let scale = UIScreen.main.scale
        let pixelSide = cellSide * scale
        let targetSize = CGSize(width: pixelSide, height: pixelSide)

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        // Use AsyncStream so both the low-res (degraded) and final deliveries are handled
        // safely. The stream finishes when PHImageManager sends the final non-degraded result.
        let assetRef = asset
        let stream = AsyncStream<UIImage> { continuation in
            let reqID = imageManager.requestImage(
                for: assetRef,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard let image else {
                    continuation.finish()
                    return
                }
                continuation.yield(image)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                if !isDegraded {
                    continuation.finish()
                }
            }
            continuation.onTermination = { [weak imageManager] _ in
                imageManager?.cancelImageRequest(reqID)
            }
            requestID = reqID
        }

        for await image in stream {
            guard !Task.isCancelled else { break }
            let squared = Self.squareCrop(image, side: pixelSide, scale: scale)
            thumbnail = squared
        }
        requestID = PHInvalidImageRequestID
    }

    /// Center-crops `image` to a square of `side` pixels at `scale`.
    private static func squareCrop(_ image: UIImage, side: CGFloat, scale: CGFloat) -> UIImage {
        let src = image.size
        let srcScale = image.scale
        // Physical pixel dimensions
        let pw = src.width * srcScale
        let ph = src.height * srcScale
        let smallerSide = min(pw, ph)
        let cropRect = CGRect(
            x: (pw - smallerSide) / 2,
            y: (ph - smallerSide) / 2,
            width: smallerSide,
            height: smallerSide
        )
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage, scale: srcScale, orientation: image.imageOrientation)
    }
}
