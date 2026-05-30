import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import UIKit
import DesignSystem
import Localization
import SplickDomain
import FeatureMedia

public struct CreatePostComposeView: View {
    @EnvironmentObject private var languageService: LanguageService
    @StateObject private var viewModel: CreatePostComposeViewModel
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    let onPosted: (Post) -> Void
    let onCancel: () -> Void
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotoLibraryPicker = false

    public init(
        viewModel: @autoclosure @escaping () -> CreatePostComposeViewModel,
        onPosted: @escaping (Post) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel())
        self.onPosted = onPosted
        self.onCancel = onCancel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                mediaPreview
                captionSection
                tagFriendsSection
                locationSection
                billSplitSection
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
                    Task {
                        if let post = await viewModel.submit() {
                            onPosted(post)
                        }
                    }
                }
                .disabled(viewModel.submitState.isLoading)
            }
        }
        .overlay {
            if viewModel.submitState.isLoading {
                LoadingView(message: languageService.text(.feedCreatePosting))
                    .background(.ultraThinMaterial)
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
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
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
                                    showPhotoLibraryPicker = true
                                } label: {
                                    Label("Chọn ảnh", systemImage: "photo.on.rectangle")
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
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.feedCreateCaption))
                .font(SplickTheme.Typography.headline)
            TextField(
                "Viết gì đó về khoảnh khắc này...",
                text: Binding(
                    get: { viewModel.caption },
                    set: { viewModel.updateCaptionMentions($0) }
                ),
                axis: .vertical
            )
                .lineLimit(3...6)
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))

            if viewModel.isSearchingMentions {
                SplickSpinner(size: .small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !viewModel.mentionSuggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(viewModel.mentionSuggestions.prefix(6)) { user in
                        Button {
                            viewModel.insertMention(user)
                        } label: {
                            HStack(spacing: SplickTheme.Spacing.sm) {
                                AvatarView(
                                    imageURL: user.avatarURL,
                                    name: user.displayName,
                                    size: .small
                                )
                                Text(user.displayName)
                                    .font(SplickTheme.Typography.callout)
                                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                                Spacer()
                                Text("@\(user.username)")
                                    .font(SplickTheme.Typography.caption)
                                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                            }
                            .padding(.horizontal, SplickTheme.Spacing.sm)
                            .padding(.vertical, SplickTheme.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
            }
        }
    }

    private var tagFriendsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text(languageService.text(.feedCreateTagFriends))
                .font(SplickTheme.Typography.headline)

            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                TextField("Tìm bạn bè...", text: $viewModel.friendSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.friendSearchQuery) { query in
                        viewModel.updateFriendSearch(query)
                    }
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))

            if !viewModel.selectedCompanions.isEmpty {
                FlowLayout(spacing: SplickTheme.Spacing.xs) {
                    ForEach(viewModel.selectedCompanions) { friend in
                        HStack(spacing: 4) {
                            Text(friend.displayName)
                                .font(SplickTheme.Typography.caption)
                            Button {
                                viewModel.removeCompanion(friend)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, SplickTheme.Spacing.sm)
                        .padding(.vertical, SplickTheme.Spacing.xxs)
                        .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                        .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                        .clipShape(Capsule())
                    }
                }
            }

            if viewModel.isSearchingFriends {
                SplickSpinner(size: .small)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if !viewModel.friendSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                friendSearchResultsList
            }
        }
    }

    @ViewBuilder
    private var friendSearchResultsList: some View {
        VStack(spacing: 0) {
            if viewModel.friendSearchResults.isEmpty {
                Text(languageService.text(.feedCreateFriendsNotFound))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SplickTheme.Spacing.sm)
            } else {
                ForEach(viewModel.friendSearchResults) { friend in
                    Button {
                        viewModel.addCompanion(friend)
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
                            Spacer()
                        }
                        .padding(.horizontal, SplickTheme.Spacing.sm)
                        .padding(.vertical, SplickTheme.Spacing.xs)
                    }
                    .buttonStyle(.plain)

                    if friend.id != viewModel.friendSearchResults.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
        .background(SplickTheme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text(languageService.text(.feedCreateLocation))
                .font(SplickTheme.Typography.headline)
            SplickTextField("Quán, địa điểm, thành phố...", text: $viewModel.location)
        }
    }

    private var billSplitSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            Toggle("Chia bill", isOn: $viewModel.enableBillSplit)
                .font(SplickTheme.Typography.headline)

            if viewModel.enableBillSplit {
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
                } else {
                    billSplitDetailFields
                }
            }
        }
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
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
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
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
            }
            if let share = viewModel.equalShareAmount {
                ForEach(viewModel.billSplitParticipants) { user in
                    HStack {
                        participantNameLabel(user)
                        Spacer()
                        Text(VNDMoneyFormat.formatDisplay(share))
                            .font(SplickTheme.Typography.callout)
                            .foregroundStyle(
                                viewModel.isCurrentUser(user)
                                    ? SplickTheme.Colors.primaryGradientStart
                                    : SplickTheme.Colors.textSecondary
                            )
                    }
                    .padding(.vertical, SplickTheme.Spacing.xxs)
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

    private func participantNameLabel(_ user: UserSummary) -> some View {
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

    private func percentageRow(for user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            participantNameLabel(user)
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
        .padding(.vertical, SplickTheme.Spacing.xxs)
    }

    private func exactAmountRow(for user: UserSummary) -> some View {
        HStack(spacing: SplickTheme.Spacing.sm) {
            participantNameLabel(user)

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
        .padding(.vertical, SplickTheme.Spacing.xxs)
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

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
