import Foundation

class TodoistService {
    let apiToken: String
    let baseURL: String

    init(apiToken: String, baseURL: String = "https://api.todoist.com/rest/v2") {
        self.apiToken = apiToken
        self.baseURL = baseURL
    }

    /// Creates a task in Todoist
    /// Returns true if successful, throws error otherwise
    func createTask(_ task: TodoistTask) async throws {
        let url = URL(string: "\(baseURL)/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode task
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(task)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.networkError(URLError(.badServerResponse))
        }

        // Check status code
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            return
        case 401:
            throw SyncError.todoistAuthFailed
        case 429:
            // Rate limited
            throw SyncError.invalidAPIResponse("Rate limited by Todoist API")
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SyncError.invalidAPIResponse("HTTP \(httpResponse.statusCode): \(errorBody)")
        }
    }
}
