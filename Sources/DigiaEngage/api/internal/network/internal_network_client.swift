import Foundation

struct InternalNetworkClient: ConfigNetworkClient {
    let baseURL: String
    let defaultHeaders: [String: String]
    let timeoutInterval: TimeInterval
    let session: URLSession

    init(
        baseURL: String,
        defaultHeaders: [String: String] = [:],
        timeout: Duration = .seconds(30),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        timeoutInterval = Self.timeoutSeconds(from: timeout)
        self.session = session
    }

    func fetchJSON(path: String, headers: [String: String], body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: baseURL + path) else {
            throw DigiaConfigError.network("Invalid URL: \(baseURL + path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.allHTTPHeaderFields = defaultHeaders
            .merging(headers) { _, rhs in rhs }
            .merging(["Content-Type": "application/json"]) { _, rhs in rhs }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw DigiaConfigError.network("Config metadata request failed")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DigiaConfigError.decodeFailure("Config metadata JSON is not an object")
        }
        return object
    }

    func download(url: String) async throws -> Data {
        guard let resolvedURL = URL(string: url) else {
            throw DigiaConfigError.network("Invalid download URL: \(url)")
        }

        var request = URLRequest(url: resolvedURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutInterval
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ..< 300).contains(httpResponse.statusCode)
        else {
            throw DigiaConfigError.network("Config file download failed")
        }
        return data
    }

    private static func timeoutSeconds(from duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
