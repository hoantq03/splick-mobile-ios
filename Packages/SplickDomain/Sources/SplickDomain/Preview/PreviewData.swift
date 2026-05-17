import Foundation

#if DEBUG
public enum PreviewData {

    // MARK: - Users

    public static let currentUser = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        email: "nam@splick.app",
        username: "namtran",
        displayName: "Nam Tran",
        avatarURL: nil,
        createdAt: .now
    )

    public static let friendUser = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        username: "linhpham",
        displayName: "Linh Pham",
        avatarURL: nil
    )

    public static let friend2 = UserSummary(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        username: "ducnguyen",
        displayName: "Duc Nguyen",
        avatarURL: nil
    )

    // MARK: - Posts

    public static let samplePost = Post(
        id: UUID(),
        author: friendUser,
        imageURL: URL(string: "https://picsum.photos/400/500")!,
        thumbnailURL: nil,
        caption: "Coffee time with the crew ☕️",
        reactions: [
            Reaction(id: UUID(), emoji: "❤️", userId: currentUser.id),
            Reaction(id: UUID(), emoji: "🔥", userId: friend2.id),
        ],
        groupId: nil,
        createdAt: Date().addingTimeInterval(-3600)
    )

    public static let samplePosts: [Post] = [
        samplePost,
        Post(
            id: UUID(),
            author: UserSummary(
                id: UUID(), username: "minhthu",
                displayName: "Minh Thu", avatarURL: nil
            ),
            imageURL: URL(string: "https://picsum.photos/400/600")!,
            caption: "Sunset vibes 🌅",
            reactions: [],
            createdAt: Date().addingTimeInterval(-7200)
        ),
        Post(
            id: UUID(),
            author: friend2,
            imageURL: URL(string: "https://picsum.photos/400/400")!,
            caption: nil,
            reactions: [Reaction(id: UUID(), emoji: "😍", userId: currentUser.id)],
            createdAt: Date().addingTimeInterval(-86400)
        ),
    ]

    // MARK: - Expenses

    public static let sampleExpense = Expense(
        id: UUID(),
        description: "Dinner at Korean BBQ",
        totalAmount: 450000,
        currency: "VND",
        paidBy: friendUser,
        splits: [
            ExpenseSplit(id: UUID(), user: friendUser, amount: 150000, isPaid: true),
            ExpenseSplit(id: UUID(), user: friend2, amount: 150000, isPaid: false),
            ExpenseSplit(
                id: UUID(),
                user: UserSummary(
                    id: currentUser.id, username: currentUser.username,
                    displayName: currentUser.displayName, avatarURL: nil
                ),
                amount: 150000, isPaid: false
            ),
        ],
        groupId: nil,
        category: .food,
        status: .pending,
        createdAt: Date().addingTimeInterval(-3600)
    )

    public static let sampleExpenses: [Expense] = [
        sampleExpense,
        Expense(
            id: UUID(),
            description: "Grab to District 1",
            totalAmount: 85000,
            currency: "VND",
            paidBy: UserSummary(
                id: currentUser.id, username: currentUser.username,
                displayName: currentUser.displayName, avatarURL: nil
            ),
            splits: [
                ExpenseSplit(id: UUID(), user: friendUser, amount: 42500, isPaid: true),
            ],
            category: .transport,
            status: .settled,
            createdAt: Date().addingTimeInterval(-86400)
        ),
        Expense(
            id: UUID(),
            description: "Monthly rent",
            totalAmount: 6000000,
            currency: "VND",
            paidBy: friend2,
            splits: [],
            category: .housing,
            status: .partiallySettled,
            createdAt: Date().addingTimeInterval(-172800)
        ),
    ]

    // MARK: - Debts

    public static let sampleDebts: [DebtSummary] = [
        DebtSummary(user: friendUser, amount: 150000),
        DebtSummary(user: friend2, amount: -300000),
    ]

    // MARK: - Notifications

    public static let sampleNotifications: [AppNotification] = [
        AppNotification(
            id: UUID(), type: .expenseCreated,
            title: "New Expense", body: "Linh added 'Dinner at Korean BBQ' - 450,000₫",
            isRead: false, createdAt: Date().addingTimeInterval(-1800)
        ),
        AppNotification(
            id: UUID(), type: .reaction,
            title: "New Reaction", body: "Duc reacted ❤️ to your photo",
            isRead: false, createdAt: Date().addingTimeInterval(-3600)
        ),
        AppNotification(
            id: UUID(), type: .expenseReminder,
            title: "Payment Reminder", body: "You owe Linh 150,000₫ for Korean BBQ",
            isRead: true, createdAt: Date().addingTimeInterval(-86400)
        ),
        AppNotification(
            id: UUID(), type: .friendRequest,
            title: "Friend Request", body: "Minh Thu wants to connect with you",
            isRead: true, createdAt: Date().addingTimeInterval(-172800)
        ),
    ]

    // MARK: - Groups

    public static let sampleGroup = Group(
        id: UUID(),
        name: "Roommates Q7",
        description: "Sharing expenses for apartment",
        members: [friendUser, friend2],
        createdBy: currentUser.id
    )
}
#endif
