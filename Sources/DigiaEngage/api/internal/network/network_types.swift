import Foundation

protocol ConfigNetworkClient {
    func fetchJSON(path: String, headers: [String: String], body: [String: Any]) async throws -> [String: Any]
    func download(url: String) async throws -> Data
}

enum InternalNetworkError: Error, Equatable {
    case invalidURL(String)
    case invalidResponse
    case invalidJSON
}
