struct DigiaConfigResolver {
    let config: DigiaConfig

    func getConfig() throws -> DigiaAppConfig {
        do {
            let strategy = try DigiaConfigStrategyFactory.createStrategy(for: config)
            return try strategy.getConfig()
        } catch let error as DigiaConfigError {
            throw error
        } catch {
            throw DigiaConfigError.invalidConfig("Resolver failed: \(error.localizedDescription)")
        }
    }

    func getConfigAsync() async throws -> DigiaAppConfig {
        do {
            let strategy = try DigiaConfigStrategyFactory.createStrategy(for: config)
            return try await strategy.getConfigAsync()
        } catch let error as DigiaConfigError {
            throw error
        } catch {
            throw DigiaConfigError.invalidConfig("Async resolver failed: \(error.localizedDescription)")
        }
    }
}
