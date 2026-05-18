import SwiftUI
import DesignSystem
import SplickDomain

public struct CreatePostComposeView: View {
    @StateObject private var viewModel: CreatePostComposeViewModel
    @Environment(\.tabBarScrollState) private var tabBarScrollState
    let onPosted: () -> Void
    let onCancel: () -> Void

    public init(
        viewModel: @autoclosure @escaping () -> CreatePostComposeViewModel,
        onPosted: @escaping () -> Void,
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
        .navigationTitle("Đăng Feeds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Huỷ", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Đăng") {
                    Task {
                        if await viewModel.submit() {
                            onPosted()
                        }
                    }
                }
                .disabled(viewModel.submitState.isLoading)
            }
        }
        .overlay {
            if viewModel.submitState.isLoading {
                LoadingView(message: "Đang đăng...")
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
            Button("OK", role: .cancel) { viewModel.clearSubmitError() }
        } message: {
            Text(viewModel.submitState.error ?? "")
        }
        .onAppear { tabBarScrollState?.hide() }
        .onDisappear { tabBarScrollState?.show() }
    }

    @ViewBuilder
    private var mediaPreview: some View {
        Group {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    SplickTheme.Colors.tertiaryBackground
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.medium))
    }

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            Text("Caption")
                .font(SplickTheme.Typography.headline)
            TextField("Viết gì đó về khoảnh khắc này...", text: $viewModel.caption, axis: .vertical)
                .lineLimit(3...6)
                .padding(SplickTheme.Spacing.sm)
                .background(SplickTheme.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.small))
        }
    }

    private var tagFriendsSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Gắn thẻ bạn bè")
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
                ProgressView()
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
                Text("Không tìm thấy bạn bè")
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
            Text("Vị trí")
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
                    Text("Gắn thẻ bạn bè để chia bill cùng người khác.")
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
            Text("Tổng tiền")
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(spacing: SplickTheme.Spacing.sm) {
                LiveVNDMoneyTextField(
                    text: $viewModel.billTotalText,
                    font: .systemFont(ofSize: 28, weight: .bold),
                    textColor: UIColor(SplickTheme.Colors.primaryGradientStart)
                )

                Text("đ")
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

                Text("đ")
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
