import SwiftUI

public struct NotificationInboxView: View {
    @StateObject private var viewModel: NotificationInboxViewModel
    
    public init(repository: NotificationRepository) {
        _viewModel = StateObject(wrappedValue: NotificationInboxViewModel(repository: repository))
    }
    
    public var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red)
                } else if viewModel.notifications.isEmpty {
                    Text("No notifications yet").foregroundColor(.gray)
                } else {
                    ForEach(viewModel.notifications) { item in
                        NotificationRow(item: item)
                            .onTapGesture {
                                Task {
                                    await viewModel.markAsClicked(notification: item)
                                    // Navigate to specific feature based on item.type here...
                                }
                            }
                    }
                }
            }
            .navigationTitle("Inbox")
            .refreshable {
                await viewModel.fetchNotifications()
            }
            .task {
                await viewModel.fetchNotifications()
            }
        }
    }
}

struct NotificationRow: View {
    let item: NotificationItem
    
    var body: some View {
        HStack {
            Circle()
                .fill(item.readAt == nil ? Color.blue : Color.clear)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.type)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text(item.message)
                    .font(.body)
                Text(item.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}
