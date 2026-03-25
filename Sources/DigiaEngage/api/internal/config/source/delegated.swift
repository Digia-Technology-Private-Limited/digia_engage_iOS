import Foundation

struct DelegatedConfigSource: DigiaConfigSource {
    let getConfigFn: () throws -> DigiaAppConfig
    let getConfigAsyncFn: (() async throws -> DigiaAppConfig)?

    init(
        getConfigFn: @escaping () throws -> DigiaAppConfig,
        getConfigAsyncFn: (() async throws -> DigiaAppConfig)? = nil
    ) {
        self.getConfigFn = getConfigFn
        self.getConfigAsyncFn = getConfigAsyncFn
    }

    init(_ getConfigFn: @escaping () throws -> DigiaAppConfig) {
        self.init(getConfigFn: getConfigFn, getConfigAsyncFn: nil)
    }

    func getConfig() throws -> DigiaAppConfig {
        do {
            return try getConfigFn()
        } catch let error as DigiaConfigError {
            throw error
        } catch {
            throw DigiaConfigError.invalidConfig("Delegated source failed: \(error.localizedDescription)")
        }
    }

    func getConfigAsync() async throws -> DigiaAppConfig {
        if let getConfigAsyncFn {
            do {
                return try await getConfigAsyncFn()
            } catch let error as DigiaConfigError {
                throw error
            } catch {
                throw DigiaConfigError.invalidConfig("Delegated async source failed: \(error.localizedDescription)")
            }
        }
        return try getConfig()
    }
}
