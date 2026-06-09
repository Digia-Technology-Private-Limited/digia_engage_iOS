import Foundation

enum DigiaEndpoints {
    static let production = "https://app.digia.tech"
    static let sandbox    = "https://dev.digia.tech"

    static func base(config: DigiaConfig) -> String {
        (config.developerConfig?.baseURL
            ?? (config.environment == .sandbox ? sandbox : production))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
