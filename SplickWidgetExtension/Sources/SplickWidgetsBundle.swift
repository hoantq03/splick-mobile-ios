import WidgetKit
import SwiftUI
import SplickWidgetKit

@main
struct SplickWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ExpenseSummaryWidget()
        UnreadMessagesWidget()
        LatestFriendPhotoWidget()
        FriendStreakWidget()
        QuickCaptureWidget()
        FriendRequestWidget()
        GroupExpenseWidget()
    }
}
