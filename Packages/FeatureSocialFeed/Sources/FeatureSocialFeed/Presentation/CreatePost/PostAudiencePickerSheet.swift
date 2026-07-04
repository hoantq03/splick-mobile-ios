import SwiftUI
import DesignSystem
import SplickDomain

struct PostAudiencePickerSheet: View {
    @ObservedObject var viewModel: CreatePostComposeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    audienceModeSection

                    if !viewModel.isAudiencePublic {
                        restrictedAudienceSection
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
        }
        .presentationDetents([.medium, .large])
        .task {
            await viewModel.loadAudienceGroupsIfNeeded()
        }
    }

    private var audienceModeSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Quyền xem")
                .font(SplickTheme.Typography.headline)

            VStack(spacing: SplickTheme.Spacing.sm) {
                audienceModeRow(
                    title: "Tất cả",
                    subtitle: "Hiển thị theo phạm vi mặc định của feed.",
                    isSelected: viewModel.isAudiencePublic,
                    action: viewModel.selectEveryoneAudience
                )

                audienceModeRow(
                    title: "Giới hạn",
                    subtitle: "Chỉ nhóm và người dùng bạn chọn mới xem được.",
                    isSelected: !viewModel.isAudiencePublic,
                    action: viewModel.enableRestrictedAudience
                )
            }
        }
        .splickCard()
    }

    private var restrictedAudienceSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.md) {
            Picker("Đối tượng", selection: $viewModel.audiencePickerTab) {
                ForEach(ComposeAudiencePickerTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.selectedAudienceGroups.isEmpty || !viewModel.selectedAudienceUsers.isEmpty {
                selectedAudienceSection
            }

            switch viewModel.audiencePickerTab {
            case .groups:
                audienceGroupsPicker
            case .users:
                audienceUsersPicker
            }
        }
        .splickCard()
    }

    private var selectedAudienceSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            Text("Đã chọn")
                .font(SplickTheme.Typography.callout)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            if !viewModel.selectedAudienceGroups.isEmpty {
                audienceGroupChipStrip
            }

            if !viewModel.selectedAudienceUsers.isEmpty {
                audienceUserChipStrip
            }
        }
    }

    private var audienceGroupChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                ForEach(viewModel.selectedAudienceGroups) { group in
                    removableChip(title: group.name) {
                        viewModel.removeAudienceGroup(group)
                    }
                }
            }
        }
    }

    private var audienceUserChipStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                ForEach(viewModel.selectedAudienceUsers) { user in
                    removableChip(title: user.displayName) {
                        viewModel.removeAudienceUser(user)
                    }
                }
            }
        }
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
                placeholder: "Tìm người dùng...",
                text: Binding(
                    get: { viewModel.audienceUserSearchQuery },
                    set: { viewModel.updateAudienceUserSearch($0) }
                )
            )

            if viewModel.audienceUserSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Nhập tên hoặc username để tìm người dùng cụ thể.")
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(SplickTheme.Spacing.sm)
                    .background(SplickTheme.Colors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: SplickTheme.CornerRadius.inset, style: .continuous))
            } else if viewModel.audienceUserSearchResults.isEmpty {
                if viewModel.isSearchingAudienceUsers {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, SplickTheme.Spacing.md)
                } else {
                    Text("Không tìm thấy người dùng phù hợp.")
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

    private var audienceUserResultsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.audienceUserSearchResults) { user in
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

                        Image(systemName: "plus.circle")
                            .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, SplickTheme.Spacing.sm)
                    .padding(.vertical, SplickTheme.Spacing.xs)
                }
                .buttonStyle(.plain)

                if user.id != viewModel.audienceUserSearchResults.last?.id {
                    Divider().padding(.leading, 48)
                }
            }

            if viewModel.isSearchingAudienceUsers {
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

    private func removableChip(title: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textPrimary)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(SplickTheme.Colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.tertiaryBackground)
        .clipShape(Capsule())
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
