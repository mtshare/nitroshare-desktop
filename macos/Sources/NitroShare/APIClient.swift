import Foundation

/// Talks to the NitroShare core over its local HTTP API.
///
/// The core writes the port and an auth token to `~/.NitroShare` once the API
/// server is listening; each request re-reads it so that a restarted core
/// (which picks a new port and token) is found automatically.
struct APIClient: Sendable {
    enum Failure: Error {
        case notRunning
        case badStatus(Int)
    }

    private struct Endpoint: Decodable {
        let port: Int
        let token: String
    }

    static let endpointURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".NitroShare")

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        return URLSession(configuration: configuration)
    }()

    func call(_ action: String, _ params: [String: any Sendable] = [:]) async throws -> Data {
        guard let data = try? Data(contentsOf: Self.endpointURL),
              let endpoint = try? JSONDecoder().decode(Endpoint.self, from: data),
              let url = URL(string: "http://127.0.0.1:\(endpoint.port)/api/\(action)") else {
            throw Failure.notRunning
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(endpoint.token, forHTTPHeaderField: "X-Auth-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (body, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw Failure.badStatus(status)
        }
        return body
    }

    func call<T: Decodable>(_ action: String, _ params: [String: any Sendable] = [:], as type: T.Type) async throws -> T {
        try JSONDecoder().decode(T.self, from: try await call(action, params))
    }
}
