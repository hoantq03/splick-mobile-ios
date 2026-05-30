import SwiftUI
import DesignSystem
import SplickDomain
import FeatureFriends

struct PhotoAlbumFilterBarView: View {
    @ObservedObject var viewModel: PhotoAlbumViewModel
    let fetchFriendsUseCase: FetchFriendsUseCaseProtocol?
    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol?

    @State private var captionQuery = ""
    @State private var isExpanded = false
    @State private var showFriendPicker = false
    @State private var showGroupPicker = false
    @State private var captionSearchTask: Task<Void, Never>?

    private var filters: PhotoAlbumFilters { viewModel.filters }

    var body: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            captionSearchField
            filterHeader

            if isExpanded {
                advancedFilters
            }

            if filters.hasAnyFilter {
                clearButton
            }
        }
        .splickCard(padding: SplickTheme.Spacing.sm)
        .sheet(isPresented: $showFriendPicker) {
            if let fetchFriendsUseCase {
                PhotoAlbumFriendPickerSheet(
                    fetchFriendsUseCase: fetchFriendsUseCase,
                    selectedAuthor: filters.author
                ) { author in
                    Task {
                        var updated = filters
                        updated.author = author
                        await viewModel.applyFilters(updated)
                    }
                }
            }
        }
        .sheet(isPresented: $showGroupPicker) {
            if let fetchMyGroupsUseCase {
                PhotoAlbumGroupPickerSheet(
                    fetchMyGroupsUseCase: fetchMyGroupsUseCase,
                    selectedGroup: filters.group
                ) { group in
                    Task {
                        var updated = filters
                        updated.group = group
                        await viewModel.applyFilters(updated)
                    }
                }
            }
        }
        .onAppear {
            if captionQuery.isEmpty {
                captionQuery = filters.captionQuery
            }
        }
        .onDisappear {
            captionSearchTask?.cancel()
        }
    }

    private var captionSearchField: some View {
        HStack(spacing: SplickTheme.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SplickTheme.Colors.textTertiary)
            TextField("Tìm theo caption", text: $captionQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: captionQuery) { _, newValue in
                    scheduleCaptionSearch(newValue)
                }
            if !captionQuery.isEmpty {
                Button {
                    captionQuery = ""
                    viewModel.setCaptionQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SplickTheme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, SplickTheme.Spacing.sm)
        .padding(.vertical, SplickTheme.Spacing.xs)
        .background(SplickTheme.Colors.tertiaryBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    private var filterHeader: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 12, weight: .semibold))
                Text("Bộ lọc")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(SplickTheme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var advancedFilters: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.xs) {
            filterChip(
                title: filters.author?.displayName ?? "Chọn bạn bè",
                systemImage: "person",
                isActive: filters.author != nil,
                isEnabled: fetchFriendsUseCase != nil
            ) {
                showFriendPicker = true
            }

            filterChip(
                title: filters.group?.name ?? "Chọn nhóm",
                systemImage: "person.3",
                isActive: filters.group != nil,
                isEnabled: fetchMyGroupsUseCase != nil
            ) {
                showGroupPicker = true
            }
        }
    }

    private var clearButton: some View {
        Button("Xóa bộ lọc") {
            captionQuery = ""
            Task { await viewModel.clearFilters() }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(SplickTheme.Colors.primary)
    }

    private func filterChip(
        title: String,
        systemImage: String,
        isActive: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: SplickTheme.Spacing.xs) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isActive ? SplickTheme.Colors.primary : SplickTheme.Colors.textPrimary)
            .padding(.horizontal, SplickTheme.Spacing.sm)
            .padding(.vertical, SplickTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? SplickTheme.Colors.primary.opacity(0.12) : SplickTheme.Colors.tertiaryBackground)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func scheduleCaptionSearch(_ query: String) {
        captionSearchTask?.cancel()
        captionSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                viewModel.setCaptionQuery(query)
            }
        }
    }
}

private struct PhotoAlbumFriendPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendsViewModel: MentionFriendsViewModel

    let selectedAuthor: UserSummary?
    let onSelect: (UserSummary?) -> Void

    init(
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol,
        selectedAuthor: UserSummary?,
        onSelect: @escaping (UserSummary?) -> Void
    ) {
        self.selectedAuthor = selectedAuthor
        self.onSelect = onSelect
        _friendsViewModel = StateObject(
            wrappedValue: MentionFriendsViewModel(useCase: fetchFriendsUseCase, pageSize: 30)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if selectedAuthor != nil {
                    Button("Tất cả bạn bè") {
                        onSelect(nil)
                        dismiss()
                    }
                }
                ForEach(friendsViewModel.friends) { friend in
                    Button {
                        onSelect(friend)
                        dismiss()
                    } label: {
                        HStack {
                            Text(friend.displayName)
                            Spacer()
                            if friend.id == selectedAuthor?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(SplickTheme.Colors.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lọc theo bạn bè")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                friendsViewModel.reset(query: "")
            }
        }
    }
}

private struct PhotoAlbumGroupPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    let selectedGroup: Group?
    let onSelect: (Group?) -> Void

    @State private var groups: [Group] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if groups.isEmpty {
                    Text("Bạn chưa tham gia nhóm nào")
                        .foregroundStyle(SplickTheme.Colors.textSecondary)
                } else {
                    List {
                        if selectedGroup != nil {
                            Button("Tất cả nhóm") {
                                onSelect(nil)
                                dismiss()
                            }
                        }
                        ForEach(groups) { group in
                            Button {
                                onSelect(group)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(group.name)
                                    Spacer()
                                    if group.id == selectedGroup?.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(SplickTheme.Colors.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lọc theo nhóm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
            .task {
                isLoading = true
                defer { isLoading = false }
                groups = (try? await fetchMyGroupsUseCase.execute()) ?? []
            }
        }
    }
}
