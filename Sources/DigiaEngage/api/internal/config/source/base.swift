protocol DigiaConfigSource {
    func getConfig() throws -> DigiaAppConfig
    func getConfigAsync() async throws -> DigiaAppConfig
}

extension DigiaConfigSource {
    func getConfigAsync() async throws -> DigiaAppConfig {
        try getConfig()
    }
}
