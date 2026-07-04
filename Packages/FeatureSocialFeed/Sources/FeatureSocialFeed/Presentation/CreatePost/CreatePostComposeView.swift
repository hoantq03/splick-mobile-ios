import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit
import DesignSystem
import Localization
import SplickDomain
import FeatureMedia

private enum ComposeMetrics {
    static let fieldCornerRadius: CGFloat = SplickTheme.CornerRadius.inset
    static let companionTileWidth: CGFloat = 72
    static let companionNameWidth: CGFloat = 64
}

private enum ComposeOptionRoute: Hashable {
    case companions
    case location
}

public struct CreatePostComposeView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: CreatePostComposeViewModel
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    let onPostSubmit: (PreparedPostSubmit) -> Void
    let onCancel: () -> Void
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotoLibraryPicker = false
    @State private var showCameraCapture = false
    @State private var reviewingMediaID: UUID?
    @State private var showAudiencePicker = false

    public init(
        viewModel: @autoclosure @escaping () -> CreatePostComposeViewModel,
        onPostSubmit: @escaping (PreparedPostSubmit) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onPostSubmit = onPostSubmit
        self.onCancel = onCancel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                mediaPreview
                captionSection
                billSplitSection
                audienceSection
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
                Button("Đăng") {
                    if let prepared = viewModel.prepareSubmit() {
                        onPostSubmit(prepared)
                    }
                }
            }
        }
        .alert(
            "Không thể đăng",
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
                    case .image(let image):
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
            PostAudiencePickerSheet(viewModel: viewModel)
        }
        .navigationDestination(for: ComposeOptionRoute.self) { route in
            switch route {
            case .companions:
                ComposeCompanionsEditorView(viewModel: viewModel)
            case .location:
                ComposeLocationEditorView(viewModel: viewModel)
            }
        }
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
                                    .accessibilityLabel("Xem và chỉnh sửa ảnh")
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
                                    Label("Chụp ảnh", systemImage: "camera")
                                }
                                Button {
                                    showPhotoLibraryPicker = true
                                } label: {
                                    Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                                }
                            }
                            if viewModel.remainingVideoSlots > 0 {
                                PhotosPicker(
                                    selection: $photoPickerItems,
                                    maxSelectionCount: 1,
                                    matching: .videos
                                ) {
                                    Label("Chọn video", systemImage: "video")
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
                "Viết gì đó về khoảnh khắc này...",
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
            Text("Tùy chọn khác")
                .font(SplickTheme.Typography.headline)

            NavigationLink(value: ComposeOptionRoute.companions) {
                optionRow(
                    icon: "person.crop.circle.badge.plus",
                    title: languageService.text(.feedCreateTagFriends),
                    summary: companionsSummaryText
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

    private var audienceSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Ai có thể xem bài viết")
                .font(SplickTheme.Typography.headline)

            Button {
                showAudiencePicker = true
            } label: {
                HStack(spacing: SplickTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                        Text(viewModel.audienceSummaryTitle)
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(SplickTheme.Colors.textPrimary)
                        Text(viewModel.audienceSummarySubtitle)
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
            .buttonStyle(.plain)
        }
        .splickCard()
    }

    private var companionsSummaryText: String {
        guard !viewModel.selectedCompanions.isEmpty else {
            return "Chạm để chọn bạn bè đi cùng hoặc người sẽ được tag."
        }

        if viewModel.selectedCompanions.count == 1 {
            return viewModel.selectedCompanions[0].displayName
        }

        let previewNames = viewModel.selectedCompanions.prefix(2).map(\.displayName)
        if viewModel.selectedCompanions.count <= 2 {
            return previewNames.joined(separator: ", ")
        }
        return "\(previewNames.joined(separator: ", ")) và +\(viewModel.selectedCompanions.count - 2) người khác"
    }

    private var locationSummaryText: String {
        let trimmed = viewModel.location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Chạm để thêm địa điểm hoặc nơi check-in." : trimmed
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
                "Chia bill",
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

                    Picker("Cách chia", selection: $viewModel.splitMode) {
                        ForEach(ComposeBillSplitMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.billSplitParticipants.isEmpty {
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

                    Toggle("Nhắc nhở tự động hàng ngày", isOn: $viewModel.autoReminderEnabled)
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
            }

        case .percentage:
            ForEach(viewModel.billSplitParticipants) { user in
                percentageRow(for: user)
            }

        case .exact:
            ForEach(viewModel.billSplitParticipants) { user in
                exactAmountRow(for: user)
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

    private func percentageRow(for user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            participantIdentityView(user)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                TextField("0", text: percentBinding(for: user.id))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 48)
                Text("%")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            }
            .frame(width: 72)

            Text(percentageAmountLabel(for: user.id))
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
        HStack(spacing: SplickTheme.Spacing.sm) {
            participantIdentityView(user)

            Spacer()

            HStack(spacing: 4) {
                LiveVNDMoneyTextField(
                    text: exactAmountBinding(for: user.id),
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
            return "— đ"
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
    @FocusState private var isFriendSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    Text(languageService.text(.feedCreateTagFriends))
                        .font(SplickTheme.Typography.headline)

                    HStack(spacing: SplickTheme.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(SplickTheme.Colors.textTertiary)
                        TextField("Tìm bạn bè...", text: $viewModel.friendSearchQuery)
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

                    if !viewModel.selectedCompanions.isEmpty {
                        selectedCompanionsStrip
                    }

                    if viewModel.shouldShowFriendSuggestions {
                        friendSearchResultsList
                    }
                }
                .splickCard()
            }
            .padding(SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .navigationTitle(languageService.text(.feedCreateTagFriends))
        .navigationBarTitleDisplayMode(.inline)
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

    private func selectedCompanionTile(for friend: UserSummary) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
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

            Text(companionShortName(friend))
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

    @ViewBuilder
    private var friendSearchResultsList: some View {
        VStack(spacing: 0) {
            if viewModel.friendSearchResults.isEmpty {
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
                ForEach(viewModel.friendSearchResults) { friend in
                    FriendTagRow(friend: friend) {
                        viewModel.addCompanion(friend)
                    }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
                    Text(languageService.text(.feedCreateLocation))
                        .font(SplickTheme.Typography.headline)
                    SplickTextField("Quán, địa điểm, thành phố...", text: $viewModel.location)
                }
                .splickCard()
            }
            .padding(SplickTheme.Spacing.md)
            .padding(.bottom, SplickTheme.Spacing.xl)
        }
        .navigationTitle(languageService.text(.feedCreateLocation))
        .navigationBarTitleDisplayMode(.inline)
    }
}
