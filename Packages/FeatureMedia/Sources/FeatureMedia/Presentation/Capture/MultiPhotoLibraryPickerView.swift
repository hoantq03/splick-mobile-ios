import DesignSystem
import Photos
import SwiftUI
import UIKit

/// In-app photo grid with multi-select; user confirms with the bottom bar or toolbar checkmark.
public struct MultiPhotoLibraryPickerView: View {
    public let maxSelectionCount: Int
    public let onConfirm: ([UIImage]) -> Void
    public let onCancel: () -> Void

    @StateObject private var viewModel: MultiPhotoLibraryPickerViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5),
    ]

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
                    Button("Huỷ", action: onCancel)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("Thư viện ảnh")
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
        .accessibilityLabel("Xác nhận chọn ảnh")
    }

    @ViewBuilder
    private var bottomSelectionBar: some View {
        if !viewModel.selectedAssetIDs.isEmpty {
            HStack(spacing: SplickTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đã chọn \(viewModel.selectedAssetIDs.count)/\(maxSelectionCount)")
                        .font(SplickTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Bấm ✓ để thêm vào bài viết")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Button {
                    Task { await confirmSelection() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Thêm")
                            .font(SplickTheme.Typography.callout.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.vertical, SplickTheme.Spacing.sm)
                    .background(Capsule().fill(SplickTheme.Colors.primaryGradient))
                }
                .disabled(viewModel.isImporting)
            }
            .padding(.horizontal, SplickTheme.Spacing.lg)
            .padding(.vertical, SplickTheme.Spacing.md)
            .background {
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
            Text("Đang tải thư viện...")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var photoGrid: some View {
        ScrollView {
            if viewModel.isLimitedLibraryAccess {
                limitedAccessBanner
                    .padding(.horizontal, SplickTheme.Spacing.md)
                    .padding(.top, SplickTheme.Spacing.sm)
                    .padding(.bottom, SplickTheme.Spacing.xs)
            }

            LazyVGrid(columns: columns, spacing: 1.5) {
                ForEach(viewModel.assets, id: \.localIdentifier) { asset in
                    PhotoGridCell(
                        asset: asset,
                        selectionIndex: viewModel.selectionIndex(for: asset.localIdentifier),
                        imageManager: viewModel.imageManager,
                        onTap: { viewModel.toggleSelection(for: asset.localIdentifier) }
                    )
                    .aspectRatio(1, contentMode: .fill)
                }
            }
            .padding(.horizontal, 1.5)
            .padding(.bottom, SplickTheme.Spacing.sm)
        }
    }

    private var limitedAccessBanner: some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            Image(systemName: "photo.badge.exclamationmark")
                .foregroundStyle(SplickTheme.Colors.warning)
            Text("Bạn đang cấp quyền truy cập một phần thư viện.")
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
            Text("Không có ảnh trong thư viện")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)
            Text("Chụp ảnh mới hoặc thêm ảnh vào thư viện.")
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
            Text("Cần quyền truy cập Thư viện ảnh")
                .font(SplickTheme.Typography.headline)
                .foregroundStyle(.white)
            Text("Bật quyền trong Cài đặt để chọn ảnh đăng bài.")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
            Button("Mở Cài đặt") {
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
                Text("Đang tải ảnh đã chọn...")
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

private struct PhotoGridCell: View {
    let asset: PHAsset
    let selectionIndex: Int?
    let imageManager: PHCachingImageManager
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    private var isSelected: Bool { selectionIndex != nil }

    var body: some View {
        Button(action: onTap) {
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    thumbnailContent(size: proxy.size)

                    if isSelected {
                        Color.black.opacity(0.35)
                    }

                    selectionBadge
                }
                .onAppear {
                    loadThumbnail(targetSize: proxy.size)
                }
                .onChange(of: proxy.size.width) { _ in
                    loadThumbnail(targetSize: proxy.size)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func thumbnailContent(size: CGSize) -> some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.06)
                ProgressView()
                    .tint(.white.opacity(0.5))
                    .scaleEffect(0.7)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
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
        .padding(6)
    }

    private func loadThumbnail(targetSize: CGSize) {
        guard targetSize.width > 1, targetSize.height > 1 else { return }
        let scale = UIScreen.main.scale
        let pixelSize = CGSize(width: targetSize.width * scale, height: targetSize.height * scale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        imageManager.requestImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            thumbnail = image
        }
    }
}
