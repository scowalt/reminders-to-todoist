import Foundation

// MARK: - Configuration

struct Config {
    let todoistToken: String
    let stateFilePath: String
    let apiBaseURL: String = "https://api.todoist.com/rest/v2"

    static func load() throws -> Config {
        let keychain = KeychainService()
        guard let token = keychain.getToken(
            service: "com.user.reminders-to-todoist",
            account: "todoist-api-token"
        ) else {
            throw ConfigError.tokenNotFound
        }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".config/reminders-to-todoist")
        let stateFilePath = configDir.appendingPathComponent("state.json").path

        return Config(todoistToken: token, stateFilePath: stateFilePath)
    }
}

enum ConfigError: Error {
    case tokenNotFound

    var description: String {
        switch self {
        case .tokenNotFound:
            return "Todoist API token not found in Keychain. Please run: reminders-to-todoist setup"
        }
    }
}

// MARK: - State Management

struct SyncState: Codable {
    var processedReminderIDs: Set<String>
    var lastSyncTimestamp: Date

    init() {
        self.processedReminderIDs = []
        self.lastSyncTimestamp = Date()
    }
}

// MARK: - Todoist Models

struct TodoistTask: Codable {
    let content: String
    let description: String?
    let due_date: String?
    let priority: Int
}

// MARK: - Priority Mapping

enum PriorityMapper {
    /// Maps Apple Reminders priority (0-9) to Todoist priority (1-4)
    /// - Apple: 0=none, 1-4=high, 5=medium, 6-9=low
    /// - Todoist: 1=normal, 2=medium, 3=high, 4=urgent
    static func mapToTodoist(_ applePriority: Int) -> Int {
        switch applePriority {
        case 0:
            return 1  // No priority → Normal
        case 1...4:
            return 4  // High → Urgent
        case 5:
            return 3  // Medium → High
        case 6...9:
            return 2  // Low → Medium
        default:
            return 1  // Default to normal
        }
    }
}

// MARK: - Errors

enum SyncError: Error {
    case eventKitPermissionDenied
    case todoistAuthFailed
    case networkError(Error)
    case stateFileCorrupted
    case invalidAPIResponse(String)

    var description: String {
        switch self {
        case .eventKitPermissionDenied:
            return "Reminders access denied. Please grant permission in System Settings > Privacy & Security > Reminders."
        case .todoistAuthFailed:
            return "Todoist authentication failed. Please check your API token."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .stateFileCorrupted:
            return "State file corrupted. Will rebuild from scratch."
        case .invalidAPIResponse(let message):
            return "Invalid API response: \(message)"
        }
    }
}
