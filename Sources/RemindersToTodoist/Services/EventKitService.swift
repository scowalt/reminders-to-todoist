import Foundation
import EventKit

class EventKitService {
    let eventStore = EKEventStore()

    /// Requests full access to Reminders
    /// Returns true if access was granted, false otherwise
    func requestRemindersAccess() async throws -> Bool {
        do {
            // Modern async API (macOS 13+)
            let granted = try await eventStore.requestFullAccessToReminders()
            return granted
        } catch {
            print("❌ Error requesting Reminders access: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetches all incomplete reminders from all lists
    func fetchIncompleteReminders() async throws -> [EKReminder] {
        // Check authorization status first
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess else {
            throw SyncError.eventKitPermissionDenied
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Fetch all calendars (reminder lists)
            let calendars = eventStore.calendars(for: .reminder)

            // Create predicate for incomplete reminders
            let predicate = eventStore.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: calendars
            )

            // Fetch reminders
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: SyncError.invalidAPIResponse("Failed to fetch reminders"))
                }
            }
        }
    }

    /// Deletes a reminder from Apple Reminders
    func deleteReminder(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: true)
    }

    /// Converts an EKReminder to a TodoistTask
    func convertToTodoistTask(_ reminder: EKReminder) -> TodoistTask {
        return TodoistTask(
            content: reminder.title ?? "Untitled",
            description: reminder.notes,
            due_date: formatDueDate(reminder.dueDateComponents),
            priority: PriorityMapper.mapToTodoist(reminder.priority)
        )
    }

    /// Formats a DateComponents as a due date string for Todoist (YYYY-MM-DD)
    private func formatDueDate(_ components: DateComponents?) -> String? {
        guard let components = components,
              let date = Calendar.current.date(from: components) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
