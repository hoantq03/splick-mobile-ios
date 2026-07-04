import SwiftUI
import DesignSystem
import SplickDomain

private enum AudiencePickerScrollTarget: Hashable {
    case selectionDetails
}

private enum AudienceSelectionMetrics {
    static let tileWidth: CGFloat = 72
    static let nameWidth: CGFloat = 64
}

struct PostAudiencePickerSheet: View {
    @ObservedObject var viewModel: CreatePostComposeViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                        audienceModeSection

                        if viewModel.audienceMode != .friends {
                            selectionDetailSection
                                .id(AudiencePickerScrollTarget.selectionDetails)
                        }
                    }
                    .padding(SplickTheme.Spacing.md)
                    .padding(.bottom, SplickTheme.Spacing.xl)
                }
                .navigationTitle("Ai có thể xem")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Xong") { dismiss() }
                    }
                }
                .onChange(of: viewModel.audienceMode) { mode in
                    guard mode != .friends else { return }
                    revealSelectionDetails(with: proxy)
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .task {
            switch viewModel.audienceMode {
            case .friends:
                break
            case .groups:
                await viewModel.loadAudienceGroupsIfNeeded()
            case .specificUsers, .friendsExcept:
                await viewModel.loadAudienceFriendsIfNeeded()
            }
        }
    }

    private func revealSelectionDetails(with proxy: ScrollViewProxy) {
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.28)) {
                selectedDetent = .large
            }

            try? await Task.sleep(nanoseconds: 220_000_000)

            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(AudiencePickerScrollTarget.selectionDetails, anchor: .top)
            }
        }
    }

    private var audienceModeSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Quyền xem")
                .font(SplickTheme.Typography.headline)

            VStack(spacing: SplickTheme.Spacing.sm) {
                audienceModeRow(
                    title: "Bạn bè",
                    subtitle: "Chỉ bạn bè của bạn có thể xem bài viết này.",
                    isSelected: viewModel.audienceMode == .friends,
                    action: { viewModel.selectAudienceMode(.friends) }
                )

                audienceModeRow(
                    title: "Nhóm",
                    subtitle: "Chỉ thành viên trong các nhóm bạn chọn mới xem được.",
                    isSelected: viewModel.audienceMode == .groups,
                    action: { viewModel.selectAudienceMode(.groups) }
                )

                audienceModeRow(
                    title: "Người dùng cụ thể",
                    subtitle: "Chỉ những người bạn chọn mới xem được bài viết.",
                    isSelected: viewModel.audienceMode == .specificUsers,
                    action: { viewModel.selectAudienceMode(.specificUsers) }
                )

                audienceModeRow(
                    title: "Bạn bè ngoại trừ",
                    subtitle: "Bạn bè vẫn xem được, trừ những người bạn loại ra.",
                    isSelected: viewModel.audienceMode == .friendsExcept,
                    action: { viewModel.selectAudienceMode(.friendsExcept) }
                )
            }
        }
        .splickCard()
    }

    private var selectionDetailSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            Text(selectionDetailTitle)
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            if hasSelections {
                selectedAudienceSection
            }

            switch viewModel.audienceMode {
            case .friends:
                EmptyView()
            case .groups:
                audienceGroupsPicker
            case .specificUsers, .friendsExcept:
                audienceUsersPicker
            }
        }
        .splickCard()
    }

    private var selectionDetailTitle: String {
        switch viewModel.audienceMode {
        case .friends:
            return ""
        case .groups:
            return "Chọn nhóm"
        case .specificUsers:
            return "Chọn bạn bè cụ thể"
        case .friendsExcept:
            return "Loại trừ bạn bè"
        }
    }

    private var hasSelections: Bool {
        switch viewModel.audienceMode {
        case .friends:
            return false
        case .groups:
            return !viewModel.selectedAudienceGroups.isEmpty
        case .specificUsers, .friendsExcept:
            return !viewModel.selectedAudienceUsers.isEmpty
        }
    }

    private var selectedAudienceSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Đã chọn")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            if viewModel.audienceMode == .groups, !viewModel.selectedAudienceGroups.isEmpty {
                audienceGroupChipStrip
            }

            if (viewModel.audienceMode == .specificUsers || viewModel.audienceMode == .friendsExcept),
               !viewModel.selectedAudienceUsers.isEmpty {
                audienceUserChipStrip
            }
        }
    }

    private var audienceGroupChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                ForEach(viewModel.selectedAudienceGroups) { group in
                    selectedAudienceGroupTile(for: group)
                }
            }
            .padding(.vertical, SplickTheme.Spacing.xxxs)
        }
    }

    private var audienceUserChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: SplickTheme.Spacing.sm) {
                ForEach(viewModel.selectedAudienceUsers) { user in
                    selectedAudienceUserTile(for: user)
                }
            }
            .padding(.vertical, SplickTheme.Spacing.xxxs)
        }
    }

    private func selectedAudienceGroupTile(for group: SplickDomain.Group) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                SplickTheme.Colors.primaryGradientStart.opacity(0.18),
                                lineWidth: 1
                            )
                    }

                Button {
                    viewModel.removeAudienceGroup(group)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }

            Text(shortDisplayName(group.name))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(width: AudienceSelectionMetrics.nameWidth)
        }
        .frame(width: AudienceSelectionMetrics.tileWidth)
        .padding(.vertical, SplickTheme.Spacing.xxs)
    }

    private func selectedAudienceUserTile(for user: UserSummary) -> some View {
        VStack(spacing: SplickTheme.Spacing.xs) {
            ZStack(alignment: .topTrailing) {
                AvatarView(
                    imageURL: user.avatarURL,
                    name: user.displayName,
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
                    viewModel.removeAudienceUser(user)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
            }

            Text(shortDisplayName(user.displayName, fallback: user.username))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .frame(width: AudienceSelectionMetrics.nameWidth)
        }
        .frame(width: AudienceSelectionMetrics.tileWidth)
        .padding(.vertical, SplickTheme.Spacing.xxs)
    }

    private var audienceGroupsPicker: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            searchField(
                placeholder: "Tìm nhóm...",
                text: $viewModel.audienceGroupSearchQuery
            )

            switch viewModel.audienceGroupsState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.md)
            case .failed(let message):
                Text(message)
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
            default:
                if viewModel.filteredAudienceGroups.isEmpty {
                    Text("Không tìm thấy nhóm phù hợp.")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SplickTheme.Spacing.sm)
                } else {
                    audienceGroupResultsList
                }
            }
        }
    }

    private var audienceGroupResultsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.filteredAudienceGroups) { group in
                Button {
                    viewModel.toggleAudienceGroup(group)
                } label: {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                            .frame(width: 40, height: 40)
                            .background(SplickTheme.Colors.primaryGradientStart.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                            Text(group.name)
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Text("\(group.memberCount) thành viên")
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: viewModel.isAudienceGroupSelected(group) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                viewModel.isAudienceGroupSelected(group)
                                    ? SplickTheme.Colors.primaryGradientStart
                                    : SplickTheme.Colors.textTertiary
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                }
                .buttonStyle(.plain)

                if group.id != viewModel.filteredAudienceGroups.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
    }

    private var audienceUsersPicker: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            searchField(
                placeholder: userSearchPlaceholder,
                text: Binding(
                    get: { viewModel.audienceUserSearchQuery },
                    set: { viewModel.updateAudienceUserSearch($0) }
                )
            )

            Text(userSearchEmptyHint)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SplickTheme.Spacing.xs)

            if viewModel.audienceFriendOptions.isEmpty {
                if viewModel.isLoadingAudienceFriends {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.md)
                } else {
                    Text("Không tìm thấy bạn bè phù hợp.")
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(SplickTheme.Spacing.sm)
                        .background(SplickTheme.Colors.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
                }
            } else {
                audienceUserResultsList
            }
        }
    }

    private var userSearchPlaceholder: String {
        switch viewModel.audienceMode {
        case .friendsExcept:
            return "Tìm bạn bè cần loại trừ..."
        default:
            return "Tìm bạn bè..."
        }
    }

    private var userSearchEmptyHint: String {
        switch viewModel.audienceMode {
        case .friendsExcept:
            return "Hiển thị sẵn 10 người bạn đầu tiên để bạn loại trừ nhanh."
        default:
            return "Hiển thị sẵn 10 người bạn đầu tiên để chọn nhanh người xem."
        }
    }

    private var audienceUserResultsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.audienceFriendOptions) { user in
                Button {
                    viewModel.toggleAudienceUser(user)
                } label: {
                    HStack(spacing: SplickTheme.Spacing.sm) {
                        AvatarView(
                            imageURL: user.avatarURL,
                            name: user.displayName,
                            size: .small
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(SplickTheme.Typography.callout)
                                .foregroundStyle(SplickTheme.Colors.textPrimary)
                            Text("@\(user.username)")
                                .font(SplickTheme.Typography.caption)
                                .foregroundStyle(SplickTheme.Colors.textTertiary)
                        }

                        Spacer()

                        Image(systemName: viewModel.isAudienceUserSelected(user) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                viewModel.isAudienceUserSelected(user)
                                    ? SplickTheme.Colors.primaryGradientStart
                                    : SplickTheme.Colors.textTertiary
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                }
                .buttonStyle(.plain)

                if user.id != viewModel.audienceFriendOptions.last?.id {
                    Divider().padding(.leading, 48)
                }
            }

            if viewModel.isLoadingAudienceFriends {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SplickTheme.Spacing.sm)
            }
        }
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
    }

    private func audienceModeRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SplickTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.xxxs) {
                    Text(title)
                        .font(SplickTheme.Typography.callout)
                        .foregroundStyle(SplickTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(SplickTheme.Typography.caption)
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected
                            ? SplickTheme.Colors.primaryGradientStart
                            : SplickTheme.Colors.textTertiary
                    )
            }
            .padding(SplickTheme.Spacing.sm)
            .background(SplickTheme.Colors.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func shortDisplayName(_ value: String, fallback: String? = nil) -> String {
        let trimmedName = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmedName.isEmpty ? (fallback ?? value) : trimmedName
        let shortName = resolved.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? resolved
        return shortName
    }

    private func searchField(placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(SplickTheme.Spacing.sm)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
    }
}
