import Foundation

struct RemoteNote: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
}

protocol RemoteNotesAPI {
    // PUBLIC_INTERFACE
    /// Pulls notes from the remote backend.
    func pullNotes() async throws -> [RemoteNote]

    // PUBLIC_INTERFACE
    /// Pushes local notes (including tombstones) to the remote backend.
    func pushNotes(_ notes: [RemoteNote]) async throws
}

/// URLSession-backed implementation of `RemoteNotesAPI`.
///
/// Expected backend contract (minimal REST, can be adapted later):
/// - GET    {baseURL}/notes            -> [RemoteNote]
/// - POST   {baseURL}/notes/batch      body: {"notes":[RemoteNote]} -> 200/204
///
/// This keeps the client implementation simple and makes the app buildable even if
/// the backend is not yet implemented.
final class URLSessionRemoteNotesAPI: RemoteNotesAPI {
    enum APIError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(statusCode: Int, body: String?)
        case missingBaseURL

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid remote API URL."
            case .invalidResponse:
                return "Invalid response from server."
            case let .httpError(statusCode, body):
                if let body, !body.isEmpty {
                    return "Remote API HTTP error \(statusCode): \(body)"
                }
                return "Remote API HTTP error \(statusCode)."
            case .missingBaseURL:
                return "Remote API base URL is not configured."
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // PUBLIC_INTERFACE
    /// Creates a new URLSession-backed RemoteNotesAPI.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for the notes backend (e.g. https://example.com/api).
    ///   - session: URLSession to use; defaults to `.shared`.
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = encoder
        self.decoder = decoder
    }

    // PUBLIC_INTERFACE
    /// Fetches remote notes using GET {baseURL}/notes.
    func pullNotes() async throws -> [RemoteNote] {
        let url = baseURL.appendingPathComponent("notes")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try Self.validateHTTPResponse(response, data: data)

        if data.isEmpty {
            return []
        }
        return try decoder.decode([RemoteNote].self, from: data)
    }

    // PUBLIC_INTERFACE
    /// Pushes notes using POST {baseURL}/notes/batch.
    func pushNotes(_ notes: [RemoteNote]) async throws {
        let url = baseURL.appendingPathComponent("notes").appendingPathComponent("batch")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Wrap in an object to allow future extensibility (e.g., deviceId, lastSyncToken).
        let body = PushNotesRequest(notes: notes)
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        try Self.validateHTTPResponse(response, data: data)
    }

    private struct PushNotesRequest: Codable {
        let notes: [RemoteNote]
    }

    private static func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}

final class MockRemoteNotesAPI: RemoteNotesAPI {
    func pullNotes() async throws -> [RemoteNote] {
        // Placeholder: no backend configured.
        return []
    }

    func pushNotes(_ notes: [RemoteNote]) async throws {
        // Placeholder: no backend configured.
        _ = notes
    }
}
