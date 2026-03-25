import Foundation

struct NetworkConfigSource: DigiaConfigSource {
    let baseURL: String
    let path: String
    let headers: [String: String]
    let body: [String: Any]

    func getConfig() throws -> DigiaAppConfig {
        throw DigiaConfigError.unsupportedFlavor
    }

    func getConfigAsync() async throws -> DigiaAppConfig {
        guard let url = URL(string: baseURL + path) else {
            throw DigiaConfigError.network("Invalid base URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers.merging(["Content-Type": "application/json"]) { _, rhs in rhs }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw DigiaConfigError.decodeFailure("Failed to encode config request body")
        }

        let data: Data
        do {
            let response = try await URLSession.shared.data(for: request)
            data = response.0
        } catch {
            throw DigiaConfigError.network("Failed to fetch config from network")
        }

        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw DigiaConfigError.decodeFailure("Failed to parse network config response")
        }

        if let object = json as? [String: Any],
           let dataObject = object["data"] as? [String: Any],
           let response = dataObject["response"] {
            return try DigiaAppConfig.decode(jsonObject: response)
        }

        if let object = json as? [String: Any], let response = object["response"] {
            return try DigiaAppConfig.decode(jsonObject: response)
        }

        return try DigiaAppConfig.decode(jsonObject: json)
    }
}
