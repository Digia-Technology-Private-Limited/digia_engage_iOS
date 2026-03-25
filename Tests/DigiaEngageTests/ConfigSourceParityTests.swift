import Foundation
@testable import DigiaEngage
import Testing

@Suite("Config Source Parity")
struct ConfigSourceParityTests {
    @Test("cached source decodes config from file")
    func cachedSourceDecodesConfigFromFile() throws {
        let path = try makeTempConfigFile(validConfigJSON(version: 9))
        let source = CachedConfigSource(cacheFilePath: path)

        let config = try source.getConfig()

        #expect(config.initialRoute == "home")
        #expect(config.version == 9)
    }

    @Test("cached source throws on missing cache")
    func cachedSourceThrowsOnMissingFile() {
        let source = CachedConfigSource(cacheFilePath: "/tmp/does-not-exist-\(UUID().uuidString).json")
        #expect(throws: DigiaConfigError.self) {
            _ = try source.getConfig()
        }
    }

    @Test("cached source maps malformed cache to decodeFailure")
    func cachedSourceMapsMalformedCacheToDecodeFailure() throws {
        let path = try makeTempConfigFile("{\"not\":\"a-valid-app-config\"}")
        let source = CachedConfigSource(cacheFilePath: path)

        #expect {
            _ = try source.getConfig()
        } throws: { error in
            guard case .decodeFailure = error as? DigiaConfigError else {
                return false
            }
            return true
        }
    }

    @Test("fallback source uses fallback when primary fails")
    func fallbackSourceUsesFallback() throws {
        let fallbackPath = try makeTempConfigFile(validConfigJSON(version: 4))
        let primary = DelegatedConfigSource {
            throw DigiaConfigError.invalidConfig("primary failed")
        }
        let fallback = CachedConfigSource(cacheFilePath: fallbackPath)
        let source = FallbackConfigSource(primary: primary, fallback: [fallback])

        let config = try source.getConfig()

        #expect(config.version == 4)
    }

    @Test("release cacheFirst and networkFirst are supported by factory")
    func releaseCacheFirstAndNetworkFirstAreSupported() throws {
        let localPath = try makeTempConfigFile(validConfigJSON(version: 1))
        let cacheFirstConfig = DigiaConfig(
            apiKey: "prod_123",
            flavor: .release(
                initStrategy: .cacheFirst,
                appConfigPath: localPath,
                functionsPath: "unused"
            )
        )
        let networkFirstConfig = DigiaConfig(
            apiKey: "prod_123",
            flavor: .release(
                initStrategy: .networkFirst(timeout: .seconds(1)),
                appConfigPath: localPath,
                functionsPath: "unused"
            )
        )

        let cacheFirstSource = try DigiaConfigStrategyFactory.createStrategy(for: cacheFirstConfig)
        let networkFirstSource = try DigiaConfigStrategyFactory.createStrategy(for: networkFirstConfig)

        #expect(!(cacheFirstSource is AssetConfigSource))
        #expect(!(networkFirstSource is AssetConfigSource))
    }

    @Test("network file source uses cached config when metadata says no update")
    func networkFileSourceUsesCachedConfigWhenNoUpdate() async throws {
        let cachePath = try makeTempConfigFile(validConfigJSON(version: 10))
        let client = MockConfigNetworkClient(
            metadata: [
                "versionUpdated": false,
                "appConfigFileUrl": "https://example.com/config.json",
            ],
            downloadedData: nil
        )
        let source = NetworkFileConfigSource(
            client: client,
            metadataPath: "/config/getAppConfigRelease",
            headers: [:],
            body: [:],
            cacheFilePath: cachePath
        )

        let config = try await source.getConfigAsync()

        #expect(config.version == 10)
        #expect(client.downloadCallCount == 0)
    }

    @Test("network file source downloads and caches when metadata says updated")
    func networkFileSourceDownloadsAndCachesWhenUpdated() async throws {
        let cachePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).json")
            .path
        let downloadedJSON = validConfigJSON(version: 22)
        let client = MockConfigNetworkClient(
            metadata: [
                "versionUpdated": true,
                "appConfigFileUrl": "https://example.com/config.json",
            ],
            downloadedData: Data(downloadedJSON.utf8)
        )
        let source = NetworkFileConfigSource(
            client: client,
            metadataPath: "/config/getAppConfigRelease",
            headers: [:],
            body: [:],
            cacheFilePath: cachePath
        )

        let config = try await source.getConfigAsync()
        let cachedData = try Data(contentsOf: URL(fileURLWithPath: cachePath))
        let cached = try DigiaAppConfig.decode(from: cachedData)

        #expect(config.version == 22)
        #expect(cached.version == 22)
        #expect(client.downloadCallCount == 1)
    }

    @Test("network file source maps malformed metadata payload to decodeFailure")
    func networkFileSourceMapsMalformedMetadataToDecodeFailure() async throws {
        let cachePath = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).json")
            .path
        let client = MockConfigNetworkClient(
            metadata: [
                "data": [
                    "response": "invalid-shape",
                ],
            ],
            downloadedData: nil
        )
        let source = NetworkFileConfigSource(
            client: client,
            metadataPath: "/config/getAppConfigRelease",
            headers: [:],
            body: [:],
            cacheFilePath: cachePath
        )

        await #expect {
            _ = try await source.getConfigAsync()
        } throws: { error in
            guard case .decodeFailure = error as? DigiaConfigError else {
                return false
            }
            return true
        }
    }

    @Test("network source maps invalid URL to network error")
    func networkSourceMapsInvalidURLToNetworkError() async {
        let source = NetworkConfigSource(
            baseURL: "bad:// url",
            path: "/config/getAppConfig",
            headers: [:],
            body: [:]
        )

        await #expect {
            _ = try await source.getConfigAsync()
        } throws: { error in
            guard case .network = error as? DigiaConfigError else {
                return false
            }
            return true
        }
    }

    @Test("resolver surfaces decodeFailure for malformed local config")
    func resolverSurfacesDecodeFailureForMalformedLocalConfig() throws {
        let malformedPath = try makeTempConfigFile("{\"pages\":[]}")
        let resolver = DigiaConfigResolver(
            config: DigiaConfig(
                apiKey: "prod_123",
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: malformedPath,
                    functionsPath: "unused"
                )
            )
        )

        #expect {
            _ = try resolver.getConfig()
        } throws: { error in
            guard case .decodeFailure = error as? DigiaConfigError else {
                return false
            }
            return true
        }
    }
}
