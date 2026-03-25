import Foundation

@MainActor
public enum Digia {
    /// Initializes the Digia SDK.
    public static func initialize(_ config: DigiaConfig) async throws {
        try await SDKInstance.shared.initialize(config)
    }

    public static func register(_ plugin: DigiaCEPPlugin) {
        SDKInstance.shared.register(plugin)
    }

    public static func registerFontFactory(_ factory: DUIFontFactory) {
        SDKInstance.shared.registerFontFactory(factory)
    }

    @discardableResult
    public static func onMessage(
        _ name: String,
        listener: @escaping @Sendable (JSONValue?) -> Void
    ) -> UUID {
        SDKInstance.shared.addMessageListener(name: name, listener: listener)
    }

    public static func removeMessageListener(_ name: String, token: UUID) {
        SDKInstance.shared.removeMessageListener(name: name, token: token)
    }
}
