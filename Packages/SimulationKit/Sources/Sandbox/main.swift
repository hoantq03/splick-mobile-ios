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
        ║   Windows-compatible feature flow testing       ║
        ╚══════════════════════════════════════════════════╝
        """)

        await container.seedTestData()
        print("")

        let args = CommandLine.arguments.dropFirst()
        let command = args.first ?? "all"

        switch command {
        case "auth", "login":
            await simulateAuthLogin(container)
        case "register":
            await simulateAuthRegister(container)
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

    // MARK: - All Simulations

    static func runAllSimulations(_ container: SimulationContainer) async {
        await simulateAuthLogin(container)
        print("")
        await simulateAuthRegister(container)
        print("")
        await simulateFeedFlow(container)
        print("")
        await simulateExpenseFlow(container)
        print("")
        await simulateNotificationFlow(container)
    }

    // MARK: - Auth Simulations

    static func simulateAuthLogin(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Auth.Login")
        logger.separator()
        logger.log("▶ SIMULATION: Login Flow")
        logger.separator()

        // Successful login
        logger.log("Scenario 1: Valid credentials")
        do {
            let session = try await container.loginUseCase.execute(
                email: "test@splick.app",
                password: "password123"
            )
            logger.success("Logged in as: @\(session.user.username)")
            logger.log("Token: \(session.token.accessToken.prefix(20))...")
        } catch {
            logger.failure("Unexpected error: \(error)")
        }

        print("")

        // Failed login
        logger.log("Scenario 2: Invalid credentials")
        do {
            _ = try await container.loginUseCase.execute(
                email: "test@splick.app",
                password: "wrongpassword"
            )
            logger.failure("Should have thrown error")
        } catch {
            logger.success("Correctly rejected: \(error)")
        }

        logger.separator()
    }

    static func simulateAuthRegister(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Auth.Register")
        logger.separator()
        logger.log("▶ SIMULATION: Register Flow")
        logger.separator()

        // Successful registration
        logger.log("Scenario 1: New user registration")
        do {
            let session = try await container.registerUseCase.execute(
                email: "newuser@splick.app",
                username: "newuser",
                password: "securepass123"
            )
            logger.success("Registered: @\(session.user.username) (\(session.user.email))")
        } catch {
            logger.failure("Unexpected error: \(error)")
        }

        print("")

        // Duplicate email
        logger.log("Scenario 2: Duplicate email")
        do {
            _ = try await container.registerUseCase.execute(
                email: "test@splick.app",
                username: "another",
                password: "password123"
            )
            logger.failure("Should have thrown error")
        } catch {
            logger.success("Correctly rejected duplicate: \(error)")
        }

        logger.separator()
    }

    // MARK: - Feed Simulation

    static func simulateFeedFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Feed")
        logger.separator()
        logger.log("▶ SIMULATION: Social Feed Flow")
        logger.separator()

        // Load feed page 0
        logger.log("Loading feed (page 0)...")
        do {
            let posts = try await container.fetchFeedUseCase.execute(page: 0)
            logger.success("Loaded \(posts.count) posts")

            for (i, post) in posts.prefix(3).enumerated() {
                logger.log("  [\(i+1)] @\(post.author.username): \(post.caption ?? "(no caption)") — \(post.reactions.count) reactions")
            }

            // React to first post
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

        // Load page 1 (pagination)
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

    // MARK: - Expense Simulation

    static func simulateExpenseFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "Expense")
        logger.separator()
        logger.log("▶ SIMULATION: Expense Splitting Flow")
        logger.separator()

        // Fetch existing expenses
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

        // Create new expense
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

        // Fetch debt summary
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

        print("")

        // Validation test — empty description
        logger.log("Validation test: empty description...")
        do {
            let badRequest = CreateExpenseRequest(
                description: "   ",
                totalAmount: 100000,
                participants: [UUID()]
            )
            _ = try await container.createExpenseUseCase.execute(badRequest)
            logger.failure("Should have rejected empty description")
        } catch {
            logger.success("Validation caught: \(error)")
        }

        // Validation test — zero amount
        logger.log("Validation test: zero amount...")
        do {
            let badRequest = CreateExpenseRequest(
                description: "Test",
                totalAmount: 0,
                participants: [UUID()]
            )
            _ = try await container.createExpenseUseCase.execute(badRequest)
            logger.failure("Should have rejected zero amount")
        } catch {
            logger.success("Validation caught: \(error)")
        }

        logger.separator()
    }

    // MARK: - Notification Simulation

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

            // Mark first unread as read
            if let firstUnread = unread.first {
                print("")
                logger.log("Marking notification as read: \(firstUnread.id.uuidString.prefix(8))...")
                try await container.markNotificationReadUseCase.execute(id: firstUnread.id)
                logger.success("Marked as read")
            }

            // Mark all as read
            print("")
            logger.log("Marking all as read...")
            try await container.markNotificationReadUseCase.markAllRead()
            logger.success("All marked as read")
        } catch {
            logger.failure("Error: \(error)")
        }

        logger.separator()
    }

    // MARK: - Full Flow

    static func simulateFullFlow(_ container: SimulationContainer) async {
        let logger = StateLogger(module: "FullFlow")
        logger.separator()
        logger.log("▶ SIMULATION: Complete User Journey")
        logger.separator()

        // 1. Register
        logger.log("Step 1: Register new user")
        do {
            let session = try await container.registerUseCase.execute(
                email: "journey@splick.app",
                username: "journeyuser",
                password: "test12345"
            )
            logger.success("Registered: @\(session.user.username)")
        } catch {
            logger.failure("Registration failed: \(error)")
            return
        }

        // 2. View feed
        print("")
        logger.log("Step 2: Browse feed")
        do {
            let posts = try await container.fetchFeedUseCase.execute(page: 0)
            logger.success("Feed has \(posts.count) posts")
        } catch {
            logger.failure("Feed failed: \(error)")
        }

        // 3. Create expense
        print("")
        logger.log("Step 3: Create expense after group dinner")
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

        // 4. Check notifications
        print("")
        logger.log("Step 4: Check notifications")
        do {
            let notifications = try await container.fetchNotificationsUseCase.execute(page: 0)
            let unread = notifications.filter { !$0.isRead }.count
            logger.success("\(unread) unread notifications")
        } catch {
            logger.failure("Notifications failed: \(error)")
        }

        logger.separator()
        logger.success("Full user journey completed successfully")
    }

    // MARK: - Usage

    static func printUsage() {
        print("""
        Usage: Sandbox [command]

        Commands:
          auth, login     Simulate login flow
          register        Simulate registration flow
          feed            Simulate social feed flow
          expense, split  Simulate expense splitting
          notification    Simulate notifications
          full            Simulate complete user journey
          all             Run all simulations (default)
        """)
    }
}
