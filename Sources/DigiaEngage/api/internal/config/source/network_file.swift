import Foundation

func defaultConfigCachePath() -> String {
    let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory
    return cacheDirectory.appendingPathComponent("appConfig.json").path
}

struct NetworkFileConfigSource: DigiaConfigSource {
    let client: ConfigNetworkClient
    let metadataPath: String
    let headers: [String: String]
    let body: [String: Any]
    let cacheFilePath: String

    init(
        client: ConfigNetworkClient,
        metadataPath: String,
        headers: [String: String],
        body: [String: Any],
        cacheFilePath: String = defaultConfigCachePath()
    ) {
        self.client = client
        self.metadataPath = metadataPath
        self.headers = headers
        self.body = body
        self.cacheFilePath = cacheFilePath
    }

    func getConfig() throws -> DigiaAppConfig {
        throw DigiaConfigError.unsupportedFeature("NetworkFileConfigSource requires async access")
    }

    func getConfigAsync() async throws -> DigiaAppConfig {
        let rawMetadata = try await client.fetchJSON(path: metadataPath, headers: headers, body: body)
        let metadata = normalizeMetadata(rawMetadata)

        if shouldUseCachedConfig(metadata: metadata) {
            return try CachedConfigSource(cacheFilePath: cacheFilePath).getConfig()
        }

        let fileURL = try extractFileURL(metadata: metadata)
        let data = try await client.download(url: fileURL)
        try data.write(to: URL(fileURLWithPath: cacheFilePath), options: .atomic)
        return try DigiaAppConfig.decode(from: data)
    }

    private func normalizeMetadata(_ value: [String: Any]) -> [String: Any] {
        if let data = value["data"] as? [String: Any],
           let response = data["response"] as? [String: Any]
        {
            return response
        }
        if let response = value["response"] as? [String: Any] {
            return response
        }
        return value
    }

    private func shouldUseCachedConfig(metadata: [String: Any]) -> Bool {
        (metadata["versionUpdated"] as? Bool) == false
    }

    private func extractFileURL(metadata: [String: Any]) throws -> String {
        guard let fileURL = metadata["appConfigFileUrl"] as? String,
              !fileURL.isEmpty
        else {
            throw DigiaConfigError.decodeFailure("appConfigFileUrl missing in metadata")
        }
        return fileURL
    }
}
