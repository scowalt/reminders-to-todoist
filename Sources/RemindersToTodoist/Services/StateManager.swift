import Foundation

class StateManager {
    let stateFilePath: String

    init(stateFilePath: String) {
        self.stateFilePath = stateFilePath
    }

    /// Loads the state from disk, or returns a fresh state if file doesn't exist
    func loadState() -> SyncState {
        let fileURL = URL(fileURLWithPath: stateFilePath)

        // If file doesn't exist, return fresh state
        guard FileManager.default.fileExists(atPath: stateFilePath) else {
            return SyncState()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SyncState.self, from: data)
        } catch {
            print("⚠️  Warning: Failed to load state file (\(error.localizedDescription)). Starting fresh.")
            return SyncState()
        }
    }

    /// Saves the state to disk atomically
    func saveState(_ state: SyncState) throws {
        let fileURL = URL(fileURLWithPath: stateFilePath)
        let directory = fileURL.deletingLastPathComponent()

        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode state
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        // Write atomically (temp file + rename)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Prunes old reminder IDs to keep state file size reasonable
    /// Keeps a random sample of 1000 IDs (since Sets are unordered)
    func pruneState(_ state: inout SyncState) {
        if state.processedReminderIDs.count > 1000 {
            // Keep a random sample of 1000 IDs
            let idsToKeep = state.processedReminderIDs.prefix(1000)
            state.processedReminderIDs = Set(idsToKeep)
        }
    }
}
