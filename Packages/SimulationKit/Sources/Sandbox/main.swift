import Foundation
import SimulationKit
import SplickDomain
import FeatureExpense

@main
struct SandboxRunner {
    static func main() async {
        let container = SimulationContainer(loggerModule: "Sandbox")

        print("""
        ╔══════════════════════════════════════════════════╗
        ║       SPLICK — Simulation Sandbox (v1.0)        ║
        ║   Non-auth feature flows (feed, expense, …)     ║
        ╚══════════════════════════════════════════════════╝
        """)

        await container.seedTestData()
        print("")

        let args = CommandLine.arguments.dropFirst()
        let command = args.first ?? "all"

        switch command {
        case "auth", "login", "register":
            printAuthNotSupported(command)
        case "feed":
            await simulateFeedFlow(container)
        case "expense", "split":
            await simulateExpenseFlow(container)
        case "notification", "notif":
            await simulateNotificationFlow(container)
        case "full":
            await simulateFullFlow(container)
        case "all":
            await runAllSimulations(container)
        default:
            printUsage()
        }

        print("\n✅ Simulation complete.")
    }

    static func printAuthNotSupported(_ command: String) {
        print("""
        Auth is no longer simulated. Use the Splick iOS app against the live backend:
          • Start splick-backend (gateway :8080, auth-service :8081)
          • Register/login in the app (OTP via Mailpit: http://localhost:8025)

        Command '\(command)' skipped.
        """)
    }

    static func runAllSimulations(_ container: SimulationContainer) async {
        await simulateFeedFlow(container)
        print("")
        await simulateExpenseFlow(container)
        print("")
        await simulateNotificationFlow(container)
    }

    static func simulateFeedFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Feed")
        logger.separator()
        logger.log("▶ SIMULATION: Social Feed Flow")
        logger.separator()

        logger.log("Loading feed (page 0)...")
        do {
            let posts = try await container.fetchFeedUseCase.execute(page: 0)
            logger.success("Loaded \(posts.count) posts")

            for (i, post) in posts.prefix(3).enumerated() {
                logger.log("  [\(i+1)] @\(post.author.username): \(post.caption ?? "(no caption)") — \(post.reactions.count) reactions")
            }

            if let firstPost = posts.first {
                print("")
                logger.log("Adding reaction ❤️ to first post...")
                let reaction = try await container.reactToPostUseCase.execute(
                    postId: firstPost.id, emoji: "❤️"
                )
                logger.success("Reaction added: \(reaction.emoji) (id: \(reaction.id.uuidString.prefix(8)))")
            }
        } catch {
            logger.failure("Feed error: \(error)")
        }

        print("")
        logger.log("Loading feed (page 1) — pagination test...")
        do {
            let page2 = try await container.fetchFeedUseCase.execute(page: 1)
            logger.success("Page 2: \(page2.count) posts")
        } catch {
            logger.failure("Pagination error: \(error)")
        }

        logger.separator()
    }

    static func simulateExpenseFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Expense")
        logger.separator()
        logger.log("▶ SIMULATION: Expense Splitting Flow")
        logger.separator()

        logger.log("Loading expenses...")
        do {
            let expenses = try await container.fetchExpensesUseCase.execute(groupId: nil, page: 0)
            logger.success("Loaded \(expenses.count) expenses")

            for expense in expenses {
                logger.log("  • \(expense.description): \(expense.totalAmount)₫ [\(expense.status.rawValue)]")
            }
        } catch {
            logger.failure("Error: \(error)")
        }

        print("")
        logger.log("Creating new expense: 'Team lunch' = 600,000₫ split 3 ways...")
        do {
            let request = CreateExpenseRequest(
                description: "Team lunch at Pho 24",
                totalAmount: 600000,
                currency: "VND",
                category: .food,
                splitType: .equal,
                participants: [
                    UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                ]
            )
            let expense = try await container.createExpenseUseCase.execute(request)
            logger.success("Created expense: \(expense.id.uuidString.prefix(8))")
            logger.log("  Splits: \(expense.splits.map { "\($0.amount)₫" }.joined(separator: " | "))")
        } catch {
            logger.failure("Create error: \(error)")
        }

        print("")
        logger.log("Loading debt summary...")
        do {
            let debts = try await container.fetchDebtSummaryUseCase.execute(groupId: nil)
            for debt in debts {
                let direction = debt.isOwed ? "owed by" : "owe to"
                logger.log("  \(direction) @\(debt.user.username): \(abs(debt.amount))₫")
            }
        } catch {
            logger.failure("Debt summary error: \(error)")
        }

        logger.separator()
    }

    static func simulateNotificationFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Notification")
        logger.separator()
        logger.log("▶ SIMULATION: Notification Flow")
        logger.separator()

        do {
            let notifications = try await container.fetchNotificationsUseCase.execute(page: 0)
            let unread = notifications.filter { !$0.isRead }
            logger.success("Loaded \(notifications.count) notifications (\(unread.count) unread)")

            for n in notifications.prefix(3) {
                let status = n.isRead ? "○" : "●"
                logger.log("  \(status) [\(n.type.rawValue)] \(n.title): \(n.body)")
            }

            if let firstUnread = unread.first {
                print("")
                logger.log("Marking notification as read: \(firstUnread.id.uuidString.prefix(8))...")
                try await container.markNotificationReadUseCase.execute(id: firstUnread.id)
                logger.success("Marked as read")
            }

            print("")
            logger.log("Marking all as read...")
            try await container.markNotificationReadUseCase.markAllRead()
            logger.success("All marked as read")
        } catch {
            logger.failure("Error: \(error)")
        }

        logger.separator()
    }

    static func simulateFullFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "FullFlow")
        logger.separator()
        logger.log("▶ SIMULATION: Post-login feature journey (mock data)")
        logger.separator()

        logger.log("Step 1: Browse feed")
        do {
            let posts = try await container.fetchFeedUseCase.execute(page: 0)
            logger.success("Feed has \(posts.count) posts")
        } catch {
            logger.failure("Feed failed: \(error)")
        }

        print("")
        logger.log("Step 2: Create expense")
        do {
            let request = CreateExpenseRequest(
                description: "Group dinner celebration",
                totalAmount: 900000,
                category: .food,
                splitType: .equal,
                participants: [
                    UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                ]
            )
            let expense = try await container.createExpenseUseCase.execute(request)
            logger.success("Expense: \(expense.totalAmount)₫ split \(expense.splits.count) ways")
        } catch {
            logger.failure("Expense failed: \(error)")
        }

        print("")
        logger.log("Step 3: Check notifications")
        do {
            let notifications = try await container.fetchNotificationsUseCase.execute(page: 0)
            let unread = notifications.filter { !$0.isRead }.count
            logger.success("\(unread) unread notifications")
        } catch {
            logger.failure("Notifications failed: \(error)")
        }

        logger.separator()
        logger.success("Feature journey completed (auth uses live API in the app)")
    }

    static func printUsage() {
        print("""
        Usage: Sandbox [command]

        Commands:
          feed            Simulate social feed flow
          expense, split  Simulate expense splitting
          notification    Simulate notifications
          full            Simulate feed + expense + notifications
          all             Run all feature simulations (default)

        Auth (login/register) is not simulated — use the iOS app with splick-backend.
        """)
    }
}
