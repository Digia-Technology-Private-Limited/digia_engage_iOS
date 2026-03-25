import Foundation

struct FallbackConfigSource: DigiaConfigSource {
    let primary: DigiaConfigSource
    let fallback: [DigiaConfigSource]

    init(primary: DigiaConfigSource, fallback: [DigiaConfigSource] = []) {
        self.primary = primary
        self.fallback = fallback
    }

    func getConfig() throws -> DigiaAppConfig {
        do {
            return try primary.getConfig()
        } catch {
            for source in fallback {
                if let config = try? source.getConfig() {
                    return config
                }
            }
            throw DigiaConfigError.invalidConfig("All config sources failed")
        }
    }

    func getConfigAsync() async throws -> DigiaAppConfig {
        do {
            return try await primary.getConfigAsync()
        } catch {
            for source in fallback {
                if let config = try? await source.getConfigAsync() {
                    return config
                }
            }
            throw DigiaConfigError.invalidConfig("All config sources failed")
        }
    }
}
