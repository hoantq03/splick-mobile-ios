import Foundation
import UIKit
import AVFoundation
import Combine
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureFriends

public enum ComposeBillSplitMode: String, CaseIterable, Identifiable {
    case equal
    case percentage
    case exact

    public var id: String { rawValue }

    public var titleKey: L10nKey {
        switch self {
        case .equal: return .expenseSplitEqual
        case .percentage: return .expenseSplitPercentage
        case .exact: return .expenseSplitExact
        }
    }
}

public struct ComposePendingGuest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var displayName: String
    public var email: String

    public init(id: UUID = UUID(), displayName: String, email: String = "") {
        self.id = id
        self.displayName = displayName
        self.email = email
    }
}

public struct PreparedPostSubmit: Sendable {
    public let optimisticPost: Post
    public let input: CreatePostInput

    public init(optimisticPost: Post, input: CreatePostInput) {
        self.optimisticPost = optimisticPost
        self.input = input
    }
}

@MainActor
public final class CreatePostComposeViewModel: ObservableObject {
    @Published var caption = ""
    @Published var location = ""
    @Published private(set) var selectedPlace: PostPlace?
    @Published private(set) var nearbyPlaces: [PostPlace] = []
    @Published private(set) var searchPlaces: [PostPlace] = []
    @Published private(set) var isSearchingPlaces = false
    @Published private(set) var locationGpsAvailable = false
    @Published var friendSearchQuery = ""
    @Published private(set) var friendSearchResults: [UserSummary] = []
    @Published private(set) var selectedCompanions: [UserSummary] = []
    @Published private(set) var pendingGuests: [ComposePendingGuest] = []
    @Published private(set) var selectedCompanionGroups: [Group] = []
    @Published private(set) var expandedCompanionGroupIds: Set<UUID> = []
    @Published private(set) var loadingCompanionGroupIds: Set<UUID> = []
    @Published var enableBillSplit = false
    @Published var autoReminderEnabled = false
    @Published var billTotalText = ""
    @Published var splitMode: ComposeBillSplitMode = .equal
    @Published var percentageTexts: [UUID: String] = [:]
    @Published var exactAmountTexts: [UUID: String] = [:]
    @Published private(set) var isSearchingFriends = false
    @Published private(set) var hasMoreFriendSearch = true
    @Published private(set) var isFriendSearchActive = false
    @Published var audienceMode: PostAudienceMode = .friends
    @Published var audienceGroupSearchQuery = ""
    @Published var audienceUserSearchQuery = ""
    @Published private(set) var availableAudienceGroups: [Group] = []
    @Published private(set) var selectedAudienceGroups: [Group] = []
    @Published private(set) var selectedAudienceUsers: [UserSummary] = []
    @Published private(set) var audienceFriendOptions: [UserSummary] = []
    @Published private(set) var audienceGroupsState: LoadingState<[Group]> = .idle
    @Published private(set) var isLoadingAudienceFriends = false
    @Published private(set) var submitState: LoadingState<Post> = .idle
    @Published private(set) var selectedMediaItems: [ComposeMediaDraft] = []
    @Published private(set) var mentionPickerViewModel: MentionFriendsViewModel?
    @Published private(set) var mentionDisplayNamesByKey: [String: String] = [:]
    @Published private(set) var mentionDisplayNamesByUserId: [UUID: String] = [:]

    private let fetchFriendsUseCase: FetchFriendsUseCaseProtocol
    private let fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol
    private let fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol
    private let languageService: LanguageService
    private let currentUser: UserSummary?
    private let currentUserId: UUID?
    private let feedRepository: FeedRepositoryProtocol?
    private var friendSearchTask: Task<Void, Never>?
    private var companionGroupMembersTasks: [UUID: Task<Void, Never>] = [:]
    private var locationSearchTask: Task<Void, Never>?
    private var locationSearchCancellable: AnyCancellable?
    private var audienceFriendSearchTask: Task<Void, Never>?
    private var activeMentionQuery = ""
    private var friendSearchPage = 0
    private var friendSearchActiveQuery = ""
    private var hasLoadedAudienceGroups = false
    private var hasLoadedAudienceFriends = false
    private var hasCompletedInitialFriendFetch = false
    private var lastFriendPaginationAnchorId: UUID?
    private var companionDirectoryTask: Task<Void, Never>?
    private var deviceLat: Double?
    private var deviceLon: Double?

    private let friendSearchPageSize = 20
    private let audienceFriendPageSize = 10

    var shouldShowFriendSuggestions: Bool {
        isFriendSearchActive
            || isSearchingFriends
            || !friendSearchResults.isEmpty
            || !friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let maxMediaItems = 10

    public init(
        previewImages: [UIImage] = [],
        previewVideoURL: URL? = nil,
        previewVideoURLs: [URL] = [],
        fetchFriendsUseCase: FetchFriendsUseCaseProtocol,
        fetchMyGroupsUseCase: FetchMyGroupsUseCaseProtocol,
        fetchGroupMembersUseCase: FetchGroupMembersUseCaseProtocol,
        languageService: LanguageService,
        currentUser: UserSummary?,
        currentUserId: UUID?,
        feedRepository: FeedRepositoryProtocol? = nil
    ) {
        self.fetchFriendsUseCase = fetchFriendsUseCase
        self.fetchMyGroupsUseCase = fetchMyGroupsUseCase
        self.fetchGroupMembersUseCase = fetchGroupMembersUseCase
        self.languageService = languageService
        self.currentUser = currentUser
        self.currentUserId = currentUserId ?? currentUser?.id
        self.feedRepository = feedRepository
        var drafts: [ComposeMediaDraft] = previewImages.compactMap(Self.makeImageDraft)
        var videoURLs = previewVideoURLs
        if let previewVideoURL {
            videoURLs.insert(previewVideoURL, at: 0)
        }
        for url in videoURLs {
            guard drafts.count < maxMediaItems else { break }
            if let draft = Self.makeVideoDraft(from: url) {
                drafts.append(draft)
            }
        }
        selectedMediaItems = Array(drafts.prefix(maxMediaItems))
        observeLocationQuery()
    }

    private func observeLocationQuery() {
        locationSearchCancellable = $location
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.locationQueryDidChange()
            }
    }

    var remainingMediaSlots: Int {
        max(0, maxMediaItems - selectedMediaItems.count)
    }

    /// Legacy alias used by older call sites / previews.
    var remainingImageSlots: Int { remainingMediaSlots }

    var composerUser: UserSummary? { currentUser }

    func addImages(_ images: [UIImage]) {
        for image in images {
            guard remainingMediaSlots > 0 else { break }
            guard let draft = Self.makeImageDraft(from: image) else { continue }
            selectedMediaItems.append(draft)
        }
    }

    var selectedCompanionIds: Set<UUID> {
        Set(selectedCompanions.map(\.id))
    }

    var filteredCompanionGroups: [Group] {
        let query = friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedIds = Set(selectedCompanionGroups.map(\.id))
        let candidates = availableAudienceGroups.filter { !selectedIds.contains($0.id) }

        guard !query.isEmpty else { return Array(candidates.prefix(6)) }
        return candidates.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.inviteCode.localizedCaseInsensitiveContains(query)
                || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var selectedAudienceGroupIds: Set<UUID> {
        Set(selectedAudienceGroups.map(\.id))
    }

    var selectedAudienceUserIds: Set<UUID> {
        Set(selectedAudienceUsers.map(\.id))
    }

    var filteredAudienceGroups: [Group] {
        let query = audienceGroupSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Array(availableAudienceGroups.prefix(10)) }
        return availableAudienceGroups.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.inviteCode.localizedCaseInsensitiveContains(query)
                || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var audienceSummaryTitle: String {
        switch audienceMode {
        case .friends:
            return languageService.text(.friendsTabFriends)
        case .groups:
            return selectedAudienceGroups.isEmpty
                ? languageService.text(.feedAudienceGroups)
                : languageService.format(.feedAudienceGroupsCount, selectedAudienceGroups.count)
        case .specificUsers:
            return selectedAudienceUsers.isEmpty
                ? languageService.text(.feedAudienceUsers)
                : languageService.format(.feedAudienceUsersCount, selectedAudienceUsers.count)
        case .friendsExcept:
            return selectedAudienceUsers.isEmpty
                ? languageService.text(.feedAudienceFriendsExcept)
                : languageService.format(.feedAudienceFriendsExceptCount, selectedAudienceUsers.count)
        }
    }

    var audienceSummarySubtitle: String {
        switch audienceMode {
        case .friends:
            return languageService.text(.feedAudienceFriendsSubtitle)
        case .groups:
            if selectedAudienceGroups.isEmpty {
                return languageService.text(.feedAudienceGroupsSubtitle)
            }
            return selectedAudienceGroups.prefix(2).map(\.name).joined(separator: ", ")
        case .specificUsers:
            if selectedAudienceUsers.isEmpty {
                return languageService.text(.feedAudienceUsersSubtitle)
            }
            return selectedAudienceUsers.prefix(2).map(\.displayName).joined(separator: ", ")
        case .friendsExcept:
            if selectedAudienceUsers.isEmpty {
                return languageService.text(.feedAudienceExceptSubtitle)
            }
            return selectedAudienceUsers.prefix(2).map(\.displayName).joined(separator: ", ")
        }
    }

    var billSplitParticipants: [UserSummary] {
        var participants: [UserSummary] = []
        var seen = Set<UUID>()

        func append(_ user: UserSummary) {
            guard seen.insert(user.id).inserted else { return }
            participants.append(user)
        }

        if let currentUser {
            append(currentUser)
        }

        selectedCompanions.forEach(append)
        if enableBillSplit {
            selectedCompanionGroups.forEach { group in
                group.members.forEach(append)
            }
        }

        return participants
    }

    var companionUsersForSubmit: [UserSummary] {
        var companions: [UserSummary] = []
        var seen = Set<UUID>()

        func append(_ user: UserSummary) {
            guard user.id != currentUserId else { return }
            guard seen.insert(user.id).inserted else { return }
            companions.append(user)
        }

        selectedCompanions.forEach(append)
        selectedCompanionGroups.forEach { group in
            group.members.forEach(append)
        }

        return companions
    }

    var selectedCompanionGroupIds: Set<UUID> {
        Set(selectedCompanionGroups.map(\.id))
    }

    var selectedCompanionGroupMemberIds: Set<UUID> {
        Set(selectedCompanionGroups.flatMap(\.members).map(\.id))
    }

    var companionGroupDisplayName: String? {
        let names = selectedCompanionGroups
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        return names.joined(separator: ", ")
    }

    var isLoadingAnyCompanionGroupMembers: Bool {
        !loadingCompanionGroupIds.isEmpty
    }

    func isCompanionGroupMembersExpanded(_ group: Group) -> Bool {
        expandedCompanionGroupIds.contains(group.id)
    }

    func isLoadingCompanionGroupMembers(_ group: Group) -> Bool {
        loadingCompanionGroupIds.contains(group.id)
    }

    func addPendingGuest(displayName: String, email: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isLikelyEmail(normalizedEmail) else { return }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = name.isEmpty ? displayNameFromEmail(normalizedEmail) : name
        pendingGuests.append(ComposePendingGuest(displayName: resolvedName, email: normalizedEmail))
    }

    func removePendingGuest(_ guest: ComposePendingGuest) {
        pendingGuests.removeAll { $0.id == guest.id }
    }

    private func isLikelyEmail(_ value: String) -> Bool {
        guard let at = value.firstIndex(of: "@"), at > value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".")
    }

    private func displayNameFromEmail(_ email: String) -> String {
        let local = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? email
        let spaced = local.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ")
        return spaced.isEmpty ? email : spaced
    }

    func isCurrentUser(_ user: UserSummary) -> Bool {
        user.id == currentUserId
    }

    func locationQueryDidChange() {
        if selectedPlace?.displayName != location {
            selectedPlace = nil
        }
        scheduleLocationSearch()
    }

    func selectPlace(_ place: PostPlace) {
        selectedPlace = place
        location = place.displayName
        searchPlaces = []
    }

    func useTypedLocation() {
        let query = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        selectedPlace = PostPlace(displayName: query)
    }

    func onDeviceCoordinates(lat: Double, lon: Double) {
        deviceLat = lat
        deviceLon = lon
        locationGpsAvailable = true
        Task { await loadNearbyPlaces() }
    }

    func onLocationPermissionDenied() {
        locationGpsAvailable = false
    }

    func participantDisplayName(_ user: UserSummary) -> String {
        isCurrentUser(user) ? languageService.text(.commonMe) : user.displayName
    }

    var parsedBillTotal: Decimal? {
        VNDMoneyFormat.parse(billTotalText)
    }

    var billTotalAmountError: String? {
        guard enableBillSplit, let total = parsedBillTotal else { return nil }
        guard !VndAmountRules.isAtLeastMinimum(total) else { return nil }
        return languageService.text(.feedCreateBillAmountMinimum)
    }

    var equalShareAmount: Decimal? {
        let count = billSplitParticipants.count + pendingGuests.count
        guard let total = parsedBillTotal, count > 0 else { return nil }
        return total / Decimal(count)
    }

    var equalSharePreview: String? {
        guard let total = parsedBillTotal,
              let share = equalShareAmount
        else { return nil }
        return languageService.format(
            .feedCreateEqualSplitPreview,
            VNDMoneyFormat.formatDisplay(total),
            billSplitParticipants.count + pendingGuests.count,
            VNDMoneyFormat.formatDisplay(share)
        )
    }

    func amountForPercentage(userId: UUID) -> Decimal? {
        guard let total = parsedBillTotal,
              let pct = VNDMoneyFormat.parsePercent(percentageTexts[userId] ?? "")
        else { return nil }
        return total * pct / 100
    }

    func clearSubmitError() {
        if case .failed = submitState {
            submitState = .idle
        }
    }

    var canAddMoreMedia: Bool {
        remainingMediaSlots > 0
    }

    func removeMediaItem(id: UUID) {
        selectedMediaItems.removeAll { $0.id == id }
    }

    func updateMediaImage(id: UUID, image: UIImage) {
        guard let index = selectedMediaItems.firstIndex(where: { $0.id == id }),
              selectedMediaItems[index].mediaType == .image,
              let draft = Self.makeImageDraft(from: image)
        else { return }

        let existingId = selectedMediaItems[index].id
        selectedMediaItems[index] = ComposeMediaDraft(
            id: existingId,
            previewImage: draft.previewImage,
            mediaType: draft.mediaType,
            data: draft.data,
            mimeType: draft.mimeType,
            videoDurationSeconds: draft.videoDurationSeconds
        )
    }

    func addMediaDraft(_ media: ComposeMediaDraft) {
        guard remainingMediaSlots > 0 else { return }
        selectedMediaItems.append(media)
    }

    func addVideo(url: URL) {
        guard let draft = Self.makeVideoDraft(from: url) else { return }
        addMediaDraft(draft)
    }

    func startCompanionDirectoryLoadIfNeeded() {
        guard companionDirectoryTask == nil else { return }
        guard !hasCompletedInitialFriendFetch || !hasLoadedAudienceGroups else { return }
        companionDirectoryTask = Task { [weak self] in
            await self?.preloadFriendSuggestionsIfNeeded()
            await self?.loadCompanionGroupsIfNeeded()
            self?.companionDirectoryTask = nil
        }
    }

    func preloadFriendSuggestionsIfNeeded() async {
        guard friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !hasCompletedInitialFriendFetch else { return }
        await fetchFriendSearchPage(page: 0, reset: true)
    }

    func setFriendSearchActive(_ active: Bool) {
        isFriendSearchActive = active
        if active {
            scheduleFriendSearch(reset: true)
        } else if friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            friendSearchTask?.cancel()
            isSearchingFriends = false
        }
    }

    func updateFriendSearch(_ query: String) {
        friendSearchQuery = query
        guard shouldShowFriendSuggestions else {
            cancelFriendSearch()
            return
        }
        scheduleFriendSearch(reset: true, debounce: true)
    }

    func loadMoreFriendSearchIfNeeded(currentFriend: UserSummary?) {
        guard let currentFriend, currentFriend.id == friendSearchResults.last?.id else { return }
        guard currentFriend.id != lastFriendPaginationAnchorId else { return }
        guard hasMoreFriendSearch, !isSearchingFriends else { return }
        lastFriendPaginationAnchorId = currentFriend.id
        friendSearchTask = Task {
            await fetchFriendSearchPage(page: friendSearchPage + 1, reset: false)
        }
    }

    func syncMentionPicker(with text: String) {
        guard let context = MentionContext.active(in: text) else {
            activeMentionQuery = ""
            mentionPickerViewModel = nil
            return
        }

        let openingPicker = mentionPickerViewModel == nil
        if openingPicker {
            mentionPickerViewModel = MentionFriendsViewModel(
                useCase: fetchFriendsUseCase,
                pageSize: friendSearchPageSize
            )
        }

        if openingPicker || context.query != activeMentionQuery {
            activeMentionQuery = context.query
            mentionPickerViewModel?.reset(query: context.query)
        }
        mentionPickerViewModel?.friends.forEach { registerMentionDisplayName(for: $0) }
    }

    func insertMention(_ user: UserSummary) {
        registerMentionDisplayName(for: user)
        guard MentionContext.insertMention(userId: user.id, in: &caption) else { return }
        activeMentionQuery = ""
        mentionPickerViewModel = nil
    }

    private func registerMentionDisplayName(for user: UserSummary) {
        let trimmed = user.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = trimmed.isEmpty ? user.username : trimmed
        mentionDisplayNamesByKey[user.username.lowercased()] = display
        mentionDisplayNamesByKey[user.id.uuidString.lowercased()] = display
        mentionDisplayNamesByUserId[user.id] = display
    }

    func addCompanion(_ user: UserSummary) {
        guard !selectedCompanionIds.contains(user.id) else { return }
        if selectedCompanionGroupMemberIds.contains(user.id) { return }
        selectedCompanions.append(user)
        friendSearchResults.removeAll { $0.id == user.id }
        friendSearchQuery = ""
        scheduleFriendSearch(reset: true)
    }

    func removeCompanion(_ user: UserSummary) {
        selectedCompanions.removeAll { $0.id == user.id }
        percentageTexts.removeValue(forKey: user.id)
        exactAmountTexts.removeValue(forKey: user.id)
    }

    func loadCompanionGroupsIfNeeded() async {
        await loadAudienceGroupsIfNeeded()
    }

    func selectCompanionGroup(_ group: Group) {
        guard !selectedCompanionGroupIds.contains(group.id) else { return }
        selectedCompanionGroups.append(group)
        expandedCompanionGroupIds.remove(group.id)
        loadingCompanionGroupIds.insert(group.id)
        if case .failed = submitState {
            submitState = .idle
        }
        let task = Task {
            await loadCompanionGroupMembers(for: group)
        }
        companionGroupMembersTasks[group.id] = task
    }

    func toggleCompanionGroupMembersExpanded(_ group: Group) {
        if expandedCompanionGroupIds.contains(group.id) {
            expandedCompanionGroupIds.remove(group.id)
        } else {
            expandedCompanionGroupIds.insert(group.id)
        }
    }

    func removeCompanionGroupMember(_ user: UserSummary, from group: Group) {
        guard !isCurrentUser(user) else { return }
        guard let index = selectedCompanionGroups.firstIndex(where: { $0.id == group.id }) else { return }
        let nextMembers = selectedCompanionGroups[index].members.filter { $0.id != user.id }
        selectedCompanionGroups[index] = groupWithMembers(selectedCompanionGroups[index], members: nextMembers)
        if !selectedCompanionGroupMemberIds.contains(user.id) {
            selectedCompanions.removeAll { $0.id == user.id }
            percentageTexts.removeValue(forKey: user.id)
            exactAmountTexts.removeValue(forKey: user.id)
        }
    }

    func removeCompanionGroup(_ group: Group) {
        companionGroupMembersTasks[group.id]?.cancel()
        companionGroupMembersTasks[group.id] = nil
        selectedCompanionGroups.removeAll { $0.id == group.id }
        expandedCompanionGroupIds.remove(group.id)
        loadingCompanionGroupIds.remove(group.id)
    }

    private func loadCompanionGroupMembers(for group: Group) async {
        loadingCompanionGroupIds.insert(group.id)
        defer {
            loadingCompanionGroupIds.remove(group.id)
            companionGroupMembersTasks[group.id] = nil
        }
        do {
            let items = try await fetchGroupMembersUseCase.execute(groupId: group.id, status: "ACTIVE")
            guard !Task.isCancelled else { return }
            guard selectedCompanionGroupIds.contains(group.id) else { return }
            var seen = Set<UUID>()
            let members = items.compactMap { item -> UserSummary? in
                guard seen.insert(item.userId).inserted else { return nil }
                return UserSummary(
                    id: item.userId,
                    username: item.username,
                    displayName: item.displayName,
                    avatarURL: item.avatarURL
                )
            }
            if members.isEmpty && group.memberCount > 0 {
                submitState = .failed(languageService.text(.feedCreateLoadGroupMembersFailed))
                return
            }
            replaceSelectedCompanionGroup(groupWithMembers(group, members: members))
            if !members.isEmpty {
                expandedCompanionGroupIds.insert(group.id)
            }
        } catch {
            guard !Task.isCancelled else { return }
            guard selectedCompanionGroupIds.contains(group.id) else { return }
            submitState = .failed(languageService.text(.feedCreateLoadGroupMembersFailed))
        }
    }

    private func replaceSelectedCompanionGroup(_ group: Group) {
        guard let index = selectedCompanionGroups.firstIndex(where: { $0.id == group.id }) else { return }
        selectedCompanionGroups[index] = group
    }

    private func groupWithMembers(_ group: Group, members: [UserSummary]) -> Group {
        Group(
            id: group.id,
            name: group.name,
            inviteCode: group.inviteCode,
            description: group.description,
            avatarURL: group.avatarURL,
            members: members,
            memberCount: members.count,
            createdBy: group.createdBy,
            createdAt: group.createdAt
        )
    }

    func loadAudienceGroupsIfNeeded() async {
        guard !hasLoadedAudienceGroups else { return }
        audienceGroupsState = .loading
        do {
            let groups = try await fetchMyGroupsUseCase.execute().sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            availableAudienceGroups = groups
            audienceGroupsState = .loaded(groups)
            hasLoadedAudienceGroups = true
        } catch {
            audienceGroupsState = .failed(languageService.localizedMessage(for: error))
        }
    }

    func loadAudienceFriendsIfNeeded() async {
        guard !hasLoadedAudienceFriends else { return }
        await fetchAudienceFriends(query: "")
    }

    func selectAudienceMode(_ mode: PostAudienceMode) {
        guard audienceMode != mode else { return }
        audienceMode = mode
        selectedAudienceGroups = []
        selectedAudienceUsers = []
        audienceGroupSearchQuery = ""
        audienceUserSearchQuery = ""
        audienceFriendOptions = []
        audienceFriendSearchTask?.cancel()
        isLoadingAudienceFriends = false
        hasLoadedAudienceFriends = false

        Task {
            switch mode {
            case .friends:
                break
            case .groups:
                await loadAudienceGroupsIfNeeded()
            case .specificUsers, .friendsExcept:
                await loadAudienceFriendsIfNeeded()
            }
        }
    }

    func isAudienceGroupSelected(_ group: Group) -> Bool {
        selectedAudienceGroupIds.contains(group.id)
    }

    func toggleAudienceGroup(_ group: Group) {
        if isAudienceGroupSelected(group) {
            selectedAudienceGroups.removeAll { $0.id == group.id }
        } else {
            selectedAudienceGroups.append(group)
            selectedAudienceGroups.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    func removeAudienceGroup(_ group: Group) {
        selectedAudienceGroups.removeAll { $0.id == group.id }
    }

    func isAudienceUserSelected(_ user: UserSummary) -> Bool {
        selectedAudienceUserIds.contains(user.id)
    }

    func toggleAudienceUser(_ user: UserSummary) {
        if isAudienceUserSelected(user) {
            selectedAudienceUsers.removeAll { $0.id == user.id }
        } else {
            selectedAudienceUsers.append(user)
            selectedAudienceUsers.sort {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        }
    }

    func removeAudienceUser(_ user: UserSummary) {
        selectedAudienceUsers.removeAll { $0.id == user.id }
    }

    func updateAudienceUserSearch(_ query: String) {
        audienceUserSearchQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            audienceFriendSearchTask?.cancel()
            Task { await fetchAudienceFriends(query: "") }
            return
        }
        scheduleAudienceFriendSearch()
    }

    func prepareSubmit() -> PreparedPostSubmit? {
        guard let input = buildCreatePostInput() else { return nil }
        guard let author = currentUser else {
            submitState = .failed(languageService.text(.feedErrorAccountUnknown))
            return nil
        }

        do {
            let optimisticPost = try OptimisticPostBuilder.build(
                author: author,
                input: input,
                mediaDrafts: selectedMediaItems,
                companions: companionUsersForSubmit
            )
            submitState = .idle
            return PreparedPostSubmit(optimisticPost: optimisticPost, input: input)
        } catch {
            submitState = .failed(languageService.localizedMessage(for: error))
            return nil
        }
    }

    private func buildCreatePostInput() -> CreatePostInput? {
        guard !selectedMediaItems.isEmpty else {
            submitState = .failed(languageService.text(.feedCreateNeedMedia))
            return nil
        }

        let audience = buildAudience()
        if audience.requiresSelection {
            submitState = .failed(audienceValidationMessage(for: audience.mode))
            return nil
        }

        if isLoadingAnyCompanionGroupMembers ||
            selectedCompanionGroups.contains(where: { $0.members.isEmpty && $0.memberCount > 0 }) {
            submitState = .failed(languageService.text(.feedCreateLoadGroupMembersFailed))
            return nil
        }

        if enableBillSplit {
            if companionUsersForSubmit.isEmpty && pendingGuests.isEmpty {
                submitState = .failed(languageService.text(.feedCreateBillNeedPeople))
                return nil
            }
            guard let total = parsedBillTotal, total > 0 else {
                submitState = .failed(languageService.text(.feedCreateBillInvalid))
                return nil
            }
            guard VndAmountRules.isAtLeastMinimum(total) else {
                submitState = .failed(languageService.text(.feedCreateBillAmountMinimum))
                return nil
            }
            guard buildBillSplit() != nil else {
                submitState = .failed(languageService.text(.feedCreateBillInvalid))
                return nil
            }
        }

        return CreatePostInput(
            mediaItems: selectedMediaItems.map {
                CreatePostMediaInput(
                    data: $0.data,
                    mimeType: $0.mimeType,
                    mediaType: $0.mediaType,
                    videoDurationSeconds: $0.videoDurationSeconds
                )
            },
            caption: caption.nilIfBlank,
            companionIds: companionUsersForSubmit.map(\.id),
            companionGroupName: companionGroupDisplayName,
            checkInPlace: selectedPlace?.displayName ?? location.nilIfBlank,
            location: selectedPlace?.hasCoordinates == true ? selectedPlace : nil,
            feedKind: enableBillSplit ? .shareBill : .checkIn,
            billSplit: enableBillSplit ? buildBillSplit() : nil,
            billSplitType: enableBillSplit ? splitMode.apiSplitType : nil,
            autoReminderEnabled: enableBillSplit && autoReminderEnabled,
            pendingCompanions: enableBillSplit
                ? pendingGuests.map {
                    PendingCompanionInput(
                        displayName: $0.displayName,
                        email: $0.email.nilIfBlank,
                        amount: pendingGuestAmount($0)
                    )
                }
                : [],
            audience: audience,
            groupId: selectedCompanionGroups.first?.id,
            groupIds: selectedCompanionGroups.map(\.id)
        )
    }

    private func buildAudience() -> PostAudience {
        switch audienceMode {
        case .friends:
            return .friends
        case .groups:
            return PostAudience(mode: .groups, allowedGroupIds: selectedAudienceGroups.map(\.id))
        case .specificUsers:
            return PostAudience(mode: .specificUsers, allowedUserIds: selectedAudienceUsers.map(\.id))
        case .friendsExcept:
            return PostAudience(mode: .friendsExcept, excludedUserIds: selectedAudienceUsers.map(\.id))
        }
    }

    private func pendingGuestAmount(_ guest: ComposePendingGuest) -> Decimal? {
        switch splitMode {
        case .equal:
            return nil
        case .exact:
            return VNDMoneyFormat.parse(exactAmountTexts[guest.id] ?? "")
        case .percentage:
            guard let total = parsedBillTotal else { return nil }
            let pct = VNDMoneyFormat.parsePercent(percentageTexts[guest.id] ?? "") ?? 0
            return total * pct / 100
        }
    }

    private func buildBillSplit() -> PostBillSplit? {
        guard let total = parsedBillTotal, VndAmountRules.isAtLeastMinimum(total) else { return nil }

        let participants = billSplitParticipants
        let guestCount = pendingGuests.count
        guard !participants.isEmpty || guestCount > 0 else { return nil }
        let partyCount = participants.count + guestCount
        guard partyCount > 0 else { return nil }

        var splits: [PostBillSplitLine]
        switch splitMode {
        case .equal:
            let share = total / Decimal(partyCount)
            splits = participants.map {
                PostBillSplitLine(user: $0, amount: share, isPaid: $0.id == currentUserId)
            }
            splits += pendingGuests.map {
                PostBillSplitLine(
                    guest: GuestParticipant(displayName: $0.displayName),
                    amount: share
                )
            }
        case .percentage:
            splits = participants.map { user in
                let pct = VNDMoneyFormat.parsePercent(percentageTexts[user.id] ?? "") ?? 0
                let amount = total * pct / 100
                return PostBillSplitLine(user: user, amount: amount, isPaid: user.id == currentUserId)
            }
            splits += pendingGuests.map { guest in
                let pct = VNDMoneyFormat.parsePercent(percentageTexts[guest.id] ?? "") ?? 0
                let amount = total * pct / 100
                return PostBillSplitLine(
                    guest: GuestParticipant(displayName: guest.displayName),
                    amount: amount
                )
            }
        case .exact:
            splits = participants.map { user in
                let amount = VNDMoneyFormat.parse(exactAmountTexts[user.id] ?? "") ?? 0
                return PostBillSplitLine(user: user, amount: amount, isPaid: user.id == currentUserId)
            }
            splits += pendingGuests.map { guest in
                let amount = VNDMoneyFormat.parse(exactAmountTexts[guest.id] ?? "") ?? 0
                return PostBillSplitLine(
                    guest: GuestParticipant(displayName: guest.displayName),
                    amount: amount
                )
            }
        }

        return PostBillSplit(totalAmount: total, currency: "VND", splits: splits)
    }

    private func cancelFriendSearch() {
        friendSearchTask?.cancel()
        friendSearchResults = []
        friendSearchPage = 0
        friendSearchActiveQuery = ""
        hasMoreFriendSearch = true
        isSearchingFriends = false
        lastFriendPaginationAnchorId = nil
        hasCompletedInitialFriendFetch = false
    }

    private func scheduleFriendSearch(reset: Bool, debounce: Bool = false) {
        friendSearchTask?.cancel()
        let trimmed = friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        friendSearchActiveQuery = trimmed.replacingOccurrences(of: "@", with: "")
        if reset {
            friendSearchPage = 0
            hasMoreFriendSearch = true
            lastFriendPaginationAnchorId = nil
        }
        friendSearchTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard !Task.isCancelled else { return }
            await fetchFriendSearchPage(page: reset ? 0 : friendSearchPage + 1, reset: reset)
        }
    }

    private func scheduleLocationSearch() {
        locationSearchTask?.cancel()
        let query = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchPlaces = []
            isSearchingPlaces = false
            return
        }
        isSearchingPlaces = true
        locationSearchTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            guard let feedRepository else {
                isSearchingPlaces = false
                return
            }
            do {
                let results = try await feedRepository.searchLocations(
                    query: query,
                    lat: deviceLat,
                    lon: deviceLon
                )
                guard !Task.isCancelled else { return }
                guard location.trimmingCharacters(in: .whitespacesAndNewlines) == query else {
                    isSearchingPlaces = false
                    return
                }
                searchPlaces = results
            } catch {
                if !Task.isCancelled {
                    searchPlaces = []
                }
            }
            isSearchingPlaces = false
        }
    }

    private func loadNearbyPlaces() async {
        guard let feedRepository, let deviceLat, let deviceLon else { return }
        do {
            nearbyPlaces = try await feedRepository.nearbyLocations(
                lat: deviceLat,
                lon: deviceLon,
                radiusMeters: 2000
            )
        } catch {
            nearbyPlaces = []
        }
    }

    private func audienceValidationMessage(for mode: PostAudienceMode) -> String {
        switch mode {
        case .friends:
            return ""
        case .groups:
            return languageService.text(.feedAudienceNeedGroup)
        case .specificUsers:
            return languageService.text(.feedAudienceNeedUser)
        case .friendsExcept:
            return languageService.text(.feedAudienceNeedExcept)
        }
    }

    private func scheduleAudienceFriendSearch() {
        audienceFriendSearchTask?.cancel()
        let query = audienceUserSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            Task { await fetchAudienceFriends(query: "") }
            return
        }

        isLoadingAudienceFriends = true
        audienceFriendSearchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await fetchAudienceFriends(query: query)
        }
    }

    private func fetchFriendSearchPage(page: Int, reset: Bool) async {
        if !reset || friendSearchResults.isEmpty {
            isSearchingFriends = true
        }
        defer {
            isSearchingFriends = false
        }

        do {
            let results = try await fetchFriendsUseCase.execute(
                query: friendSearchActiveQuery,
                page: page,
                limit: friendSearchPageSize
            )
            guard !Task.isCancelled else { return }
            let excludedIds = selectedCompanionIds.union(selectedCompanionGroupMemberIds)
            let filtered = results
                .filter { !excludedIds.contains($0.id) }
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                        == .orderedAscending
                }
            if reset {
                friendSearchResults = filtered
                hasMoreFriendSearch = results.count == friendSearchPageSize
            } else {
                let existingIds = Set(friendSearchResults.map(\.id))
                let appended = filtered.filter { !existingIds.contains($0.id) }
                friendSearchResults.append(contentsOf: appended)
                friendSearchResults.sort {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                        == .orderedAscending
                }
                hasMoreFriendSearch = results.count == friendSearchPageSize && !appended.isEmpty
            }
            friendSearchPage = page
            if reset, friendSearchActiveQuery.isEmpty {
                hasCompletedInitialFriendFetch = true
            }
        } catch {
            if reset {
                friendSearchResults = []
                if friendSearchActiveQuery.isEmpty {
                    hasCompletedInitialFriendFetch = true
                }
            }
            hasMoreFriendSearch = false
        }
    }

    private func fetchAudienceFriends(query: String) async {
        isLoadingAudienceFriends = true
        defer { isLoadingAudienceFriends = false }

        do {
            let results = try await fetchFriendsUseCase.execute(
                query: query,
                page: 0,
                limit: audienceFriendPageSize
            )
            guard !Task.isCancelled else { return }
            audienceFriendOptions = results
                .sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
            if query.isEmpty {
                hasLoadedAudienceFriends = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            audienceFriendOptions = []
        }
    }

    private static func makeImageDraft(from previewImage: UIImage) -> ComposeMediaDraft? {
        let jpegData = previewImage.jpegData(compressionQuality: AppConstants.Media.compressionQuality)
        let pngData = jpegData == nil ? previewImage.pngData() : nil
        guard let data = jpegData ?? pngData else { return nil }
        return ComposeMediaDraft(
            previewImage: previewImage,
            mediaType: .image,
            data: data,
            mimeType: jpegData != nil ? "image/jpeg" : "image/png",
            videoDurationSeconds: nil
        )
    }

    private static func makeVideoDraft(from url: URL) -> ComposeMediaDraft? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        let asset = AVURLAsset(url: url)
        let duration = Int(round(CMTimeGetSeconds(asset.duration)))
        var preview: UIImage?
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
            preview = UIImage(cgImage: cgImage)
        }
        return ComposeMediaDraft(
            previewImage: preview,
            mediaType: .video,
            data: data,
            mimeType: "video/mp4",
            videoDurationSeconds: duration > 0 ? duration : 1
        )
    }
}

public struct ComposeMediaDraft: Identifiable {
    public let id: UUID
    public let previewImage: UIImage?
    public let mediaType: PostMediaType
    public let data: Data
    public let mimeType: String
    public let videoDurationSeconds: Int?

    public init(
        id: UUID = UUID(),
        previewImage: UIImage?,
        mediaType: PostMediaType,
        data: Data,
        mimeType: String,
        videoDurationSeconds: Int?
    ) {
        self.id = id
        self.previewImage = previewImage
        self.mediaType = mediaType
        self.data = data
        self.mimeType = mimeType
        self.videoDurationSeconds = videoDurationSeconds
    }
}

private extension ComposeBillSplitMode {
    var apiSplitType: String {
        switch self {
        case .equal: return "EQUAL"
        case .percentage: return "PERCENTAGE"
        case .exact: return "EXACT"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
