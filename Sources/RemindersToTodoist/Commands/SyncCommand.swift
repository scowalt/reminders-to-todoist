import Foundation
import ArgumentParser
import EventKit

struct SyncCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Run sync operation (default command)"
    )

    func run() async throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] Starting Reminders → Todoist sync")

        // Load configuration
        let config: Config
        do {
            config = try Config.load()
        } catch {
            if let configError = error as? ConfigError {
                print("❌ \(configError.description)")
            } else {
                print("❌ Configuration error: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }

        // Load state
        let stateManager = StateManager(stateFilePath: config.stateFilePath)
        var state = stateManager.loadState()

        // Initialize services
        let eventKitService = EventKitService()
        let todoistService = TodoistService(apiToken: config.todoistToken)

        // Request EventKit permissions
        let hasAccess = try await eventKitService.requestRemindersAccess()
        guard hasAccess else {
            print("❌ \(SyncError.eventKitPermissionDenied.description)")
            throw ExitCode.failure
        }

        // Fetch all incomplete reminders
        let allReminders: [EKReminder]
        do {
            allReminders = try await eventKitService.fetchIncompleteReminders()
        } catch {
            if let syncError = error as? SyncError {
                print("❌ \(syncError.description)")
            } else {
                print("❌ Failed to fetch reminders: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }

        // Filter out already processed reminders
        let newReminders = allReminders.filter {
            !state.processedReminderIDs.contains($0.calendarItemIdentifier)
        }

        print("📝 Found \(newReminders.count) new reminders to sync")

        // Sync each new reminder
        var syncedCount = 0
        var failedCount = 0

        for reminder in newReminders {
            let title = reminder.title ?? "Untitled"

            do {
                // Convert to Todoist task
                let task = eventKitService.convertToTodoistTask(reminder)

                // Create in Todoist
                try await todoistService.createTask(task)

                // Delete from Apple Reminders
                try eventKitService.deleteReminder(reminder)

                // Mark as processed
                state.processedReminderIDs.insert(reminder.calendarItemIdentifier)
                syncedCount += 1

                print("✓ Synced: \(title)")

            } catch {
                failedCount += 1
                if let syncError = error as? SyncError {
                    print("✗ Failed to sync '\(title)': \(syncError.description)")
                } else {
                    print("✗ Failed to sync '\(title)': \(error.localizedDescription)")
                }
                // Don't mark as processed - will retry next time
            }
        }

        // Update timestamp and save state
        state.lastSyncTimestamp = Date()
        stateManager.pruneState(&state)

        do {
            try stateManager.saveState(state)
        } catch {
            print("⚠️  Warning: Failed to save state: \(error.localizedDescription)")
        }

        // Print summary
        let endTimestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(endTimestamp)] Sync complete: \(syncedCount) synced, \(failedCount) failed")
    }
}
