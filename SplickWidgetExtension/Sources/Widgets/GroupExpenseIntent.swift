import AppIntents
import WidgetKit
import SplickWidgetKit

@available(iOS 17.0, *)
struct GroupExpenseIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Chọn nhóm"
    static var description = IntentDescription("Chọn nhóm để hiển thị chi tiêu trên widget.")

    @Parameter(title: "Nhóm")
    var group: GroupEntity?

    func perform() async throws -> some IntentResult {
        .result()
    }
}

@available(iOS 17.0, *)
struct GroupEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Nhóm")
    static var defaultQuery = GroupEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 17.0, *)
struct GroupEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [GroupEntity] {
        let groups = WidgetCacheService.shared.loadGroups()?.groups ?? []
        return groups
            .filter { identifiers.contains($0.id) }
            .map { GroupEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        let groups = WidgetCacheService.shared.loadGroups()?.groups ?? []
        return groups.map { GroupEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> GroupEntity? {
        try? await suggestedEntities().first
    }
}

struct GroupExpenseEntry: TimelineEntry {
    let date: Date
    let groupId: UUID?
    let snapshot: WidgetGroupExpenseSnapshot?
}

@available(iOS 17.0, *)
struct GroupExpenseProvider: AppIntentTimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> GroupExpenseEntry {
        GroupExpenseEntry(
            date: .now,
            groupId: nil,
            snapshot: WidgetGroupExpenseSnapshot(
                groupId: UUID(),
                groupName: "Nhóm đi chơi",
                totalAmount: "1,200,000₫",
                settledPercentage: 60,
                currency: "VND",
                memberBalances: [
                    WidgetGroupMemberBalance(
                        userId: UUID(),
                        displayName: "Minh",
                        amount: "200,000₫",
                        isOwed: false
                    )
                ]
            )
        )
    }

    func snapshot(for configuration: GroupExpenseIntent, in context: Context) async -> GroupExpenseEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: GroupExpenseIntent, in context: Context) async -> Timeline<GroupExpenseEntry> {
        let entry = makeEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func makeEntry(for configuration: GroupExpenseIntent) -> GroupExpenseEntry {
        let groupId = configuration.group?.id
        let snapshot = groupId.flatMap { cache.loadGroupExpense(groupId: $0) }
        return GroupExpenseEntry(date: .now, groupId: groupId, snapshot: snapshot)
    }
}
