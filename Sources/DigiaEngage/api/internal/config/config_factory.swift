import Foundation

enum DigiaConfigStrategyFactory {
    static func createStrategy(for config: DigiaConfig) throws -> DigiaConfigSource {
        switch config.flavor {
        case let .debug(branchName):
            return NetworkConfigSource(
                baseURL: config.developerConfig?.baseURL ?? "https://app.digia.tech/api/v1",
                path: "/config/getAppConfig",
                headers: makeDigiaHeaders(config: config),
                body: branchName.map { ["branchName": $0] } ?? [:]
            )

        case .staging:
            return NetworkConfigSource(
                baseURL: config.developerConfig?.baseURL ?? "https://app.digia.tech/api/v1",
                path: "/config/getAppConfigStaging",
                headers: makeDigiaHeaders(config: config),
                body: [:]
            )

        case let .versioned(version):
            var headers = makeDigiaHeaders(config: config)
            headers["x-digia-project-version"] = "\(version)"
            return NetworkConfigSource(
                baseURL: config.developerConfig?.baseURL ?? "https://app.digia.tech/api/v1",
                path: "/config/getAppConfigForVersion",
                headers: headers,
                body: [:]
            )

        case let .release(initStrategy, appConfigPath, _):
            switch initStrategy {
            case .localFirst:
                return AssetConfigSource(appConfigPath: appConfigPath)
            case .cacheFirst:
                return DelegatedConfigSource(getConfigFn: {
                    let asset = AssetConfigSource(appConfigPath: appConfigPath)
                    let cached = CachedConfigSource(cacheFilePath: defaultConfigCachePath())
                    var configToUse = try asset.getConfig()

                    if let cachedConfig = try? cached.getConfig(),
                       (cachedConfig.version ?? Int.min) >= (configToUse.version ?? Int.min)
                    {
                        configToUse = cachedConfig
                    }

                    let networkSource = makeReleaseNetworkFileSource(config: config)
                    Task {
                        _ = try? await networkSource.getConfigAsync()
                    }

                    return configToUse
                })
            case .networkFirst:
                return DelegatedConfigSource(
                    getConfigFn: {
                        throw DigiaConfigError.unsupportedFeature("networkFirst requires async resolver path")
                    },
                    getConfigAsyncFn: {
                        let asset = AssetConfigSource(appConfigPath: appConfigPath)
                        let cached = CachedConfigSource(cacheFilePath: defaultConfigCachePath())
                        var fallbackConfig = try asset.getConfig()

                        if let cachedConfig = try? cached.getConfig(),
                           (cachedConfig.version ?? Int.min) >= (fallbackConfig.version ?? Int.min)
                        {
                            fallbackConfig = cachedConfig
                        }

                        do {
                            return try await makeReleaseNetworkFileSource(config: config).getConfigAsync()
                        } catch {
                            return fallbackConfig
                        }
                    }
                )
            }
        }
    }
}

private func makeDigiaHeaders(config: DigiaConfig) -> [String: String] {
    let bundle = Bundle.main
    let packageName = bundle.bundleIdentifier ?? "com.digia.sample"
    let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    let environment = config.environment == .production ? "production" : "sandbox"

    return [
        "x-digia-version": "ios-dev",
        "x-digia-project-id": config.apiKey,
        "x-digia-platform": "ios",
        "x-app-package-name": packageName,
        "x-app-version": appVersion,
        "x-app-build-number": buildNumber,
        "x-digia-environment": environment,
    ]
}

private func makeReleaseNetworkFileSource(config: DigiaConfig) -> NetworkFileConfigSource {
    let headers = makeDigiaHeaders(config: config)
    let client = InternalNetworkClient(
        baseURL: config.developerConfig?.baseURL ?? "https://app.digia.tech/api/v1",
        defaultHeaders: headers,
        timeout: config.networkConfiguration?.timeout ?? .seconds(30)
    )

    return NetworkFileConfigSource(
        client: client,
        metadataPath: "/config/getAppConfigRelease",
        headers: [:],
        body: [:],
        cacheFilePath: defaultConfigCachePath()
    )
}
