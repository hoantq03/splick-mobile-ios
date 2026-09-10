import WidgetKit
import SwiftUI
import SplickWidgetKit

/// iOS 16 fallback — shows the first cached group (no App Intents).
struct GroupExpenseStaticEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetGroupExpenseSnapshot?
}

struct GroupExpenseStaticProvider: TimelineProvider {
    private let cache = WidgetCacheService.shared

    func placeholder(in context: Context) -> GroupExpenseStaticEntry {
        GroupExpenseStaticEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GroupExpenseStaticEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GroupExpenseStaticEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> GroupExpenseStaticEntry {
        let groups = cache.loadGroups()?.groups ?? []
        let snapshot = groups.first.flatMap { cache.loadGroupExpense(groupId: $0.id) }
        return GroupExpenseStaticEntry(date: .now, snapshot: snapshot)
    }
}
