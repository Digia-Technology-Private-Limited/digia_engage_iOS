import Foundation
@testable import DigiaEngage
import Testing

@MainActor
@Suite("AppState Parity", .serialized)
struct AppStateParityTests {
    @Test("initializes runtime appState from config appState string descriptor")
    func initializesRuntimeAppStateFromConfig() async throws {
        SDKInstance.shared.resetForTesting()
        let configPath = try makeTempConfigFile("""
        {
          "appSettings": { "initialRoute": "home" },
          "pages": { "home": { "uid": "home" } },
          "rest": {},
          "theme": { "colors": { "light": {} } },
          "appState": [
            {
              "name": "theme",
              "type": "string",
              "value": "dark",
              "shouldPersist": false,
              "streamName": "themeStream"
            }
          ]
        }
        """)

        let config = DigiaConfig(
            apiKey: "prod_123",
            flavor: .release(
                initStrategy: .localFirst,
                appConfigPath: configPath,
                functionsPath: "unused"
            )
        )
        try await Digia.initialize(config)

        #expect(SDKInstance.shared.appState["theme"] == .string("dark"))
    }

    @Test("loads persisted value for descriptor marked shouldPersist")
    func loadsPersistedValueWhenShouldPersistTrue() throws {
        let suiteName = "digia.appstate.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let descriptor = AppStateDefinition(
            name: "theme",
            type: "string",
            value: .string("light"),
            shouldPersist: true,
            streamName: "themeStream"
        )
        defaults.set("dark", forKey: "proj_123_app_state_theme")

        let store = try AppStateStore(
            definitions: [descriptor],
            namespace: "proj_123",
            storage: defaults
        )

        #expect(store.snapshot()["theme"] == .string("dark"))
    }

    @Test("supports typed descriptors and aliases")
    func supportsTypedDescriptorsAndAliases() throws {
        let definitions = [
            AppStateDefinition(
                name: "count",
                type: "numeric",
                value: .int(3),
                shouldPersist: false,
                streamName: "countStream"
            ),
            AppStateDefinition(
                name: "enabled",
                type: "boolean",
                value: .int(1),
                shouldPersist: false,
                streamName: "enabledStream"
            ),
            AppStateDefinition(
                name: "profile",
                type: "json",
                value: .object(["id": .int(7)]),
                shouldPersist: false,
                streamName: "profileStream"
            ),
            AppStateDefinition(
                name: "items",
                type: "array",
                value: .array([.string("a"), .string("b")]),
                shouldPersist: false,
                streamName: "itemsStream"
            ),
        ]
        let store = try AppStateStore(definitions: definitions, namespace: "proj_123")
        let snapshot = store.snapshot()

        #expect(snapshot["count"] == .int(3))
        #expect(snapshot["enabled"] == .bool(true))
        #expect(snapshot["profile"] == .object(["id": .int(7)]))
        #expect(snapshot["items"] == .array([.string("a"), .string("b")]))
    }

    @Test("rejects duplicate keys and unknown types")
    func rejectsDuplicateKeysAndUnknownTypes() {
        #expect(throws: AppStateStoreError.self) {
            let defs = [
                AppStateDefinition(name: "k", type: "string", value: .string("a"), shouldPersist: false, streamName: "s1"),
                AppStateDefinition(name: "k", type: "string", value: .string("b"), shouldPersist: false, streamName: "s2"),
            ]
            _ = try AppStateStore(definitions: defs, namespace: "proj_123")
        }

        #expect(throws: AppStateStoreError.self) {
            let defs = [
                AppStateDefinition(name: "x", type: "uuid", value: .string("v"), shouldPersist: false, streamName: "xStream"),
            ]
            _ = try AppStateStore(definitions: defs, namespace: "proj_123")
        }
    }

    @Test("exposes appState map in expression scope")
    func exposesAppStateInExpressionScope() async throws {
        SDKInstance.shared.resetForTesting()
        let configPath = try makeTempConfigFile("""
        {
          "appSettings": { "initialRoute": "home" },
          "pages": { "home": { "uid": "home" } },
          "rest": {},
          "theme": { "colors": { "light": {} } },
          "appState": [
            {
              "name": "theme",
              "type": "string",
              "value": "dark",
              "shouldPersist": false,
              "streamName": "themeStream"
            }
          ]
        }
        """)

        let config = DigiaConfig(
            apiKey: "proj_123",
            flavor: .release(
                initStrategy: .localFirst,
                appConfigPath: configPath,
                functionsPath: "unused"
            )
        )
        try await Digia.initialize(config)
        let payload = RenderPayload(appConfigStore: SDKInstance.shared.appConfigStore)

        #expect(payload.eval(.expression("${appState.theme}")) == "dark")
    }

    @Test("setAppState updates a configured key and persists when enabled")
    func setAppStateUpdatesAndPersists() async throws {
        let apiKey = "proj_\(UUID().uuidString)"
        let storageKey = "\(apiKey)_app_state_count"
        UserDefaults.standard.removeObject(forKey: storageKey)
        defer {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }

        let configPath = try makeTempConfigFile("""
        {
          "appSettings": { "initialRoute": "home" },
          "pages": { "home": { "uid": "home" } },
          "rest": {},
          "theme": { "colors": { "light": {} } },
          "appState": [
            {
              "name": "count",
              "type": "number",
              "value": 1,
              "shouldPersist": true,
              "streamName": "countStream"
            }
          ]
        }
        """)

        SDKInstance.shared.resetForTesting()
        try await Digia.initialize(
            DigiaConfig(
                apiKey: apiKey,
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: configPath,
                    functionsPath: "unused"
                )
            )
        )

        let action = SetAppStateAction(
            disableActionIf: nil,
            data: ["stateKey": .string("count"), "value": .int(2)]
        )
        try await SetAppStateProcessor().execute(action: action, context: context())
        #expect(SDKInstance.shared.appState["count"] == .int(2))

        SDKInstance.shared.resetForTesting()
        try await Digia.initialize(
            DigiaConfig(
                apiKey: apiKey,
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: configPath,
                    functionsPath: "unused"
                )
            )
        )
        #expect(SDKInstance.shared.appState["count"] == .int(2))
    }

    @Test("setAppState rejects missing keys and type mismatches")
    func setAppStateRejectsInvalidUpdates() async throws {
        let configPath = try makeTempConfigFile("""
        {
          "appSettings": { "initialRoute": "home" },
          "pages": { "home": { "uid": "home" } },
          "rest": {},
          "theme": { "colors": { "light": {} } },
          "appState": [
            {
              "name": "count",
              "type": "number",
              "value": 1,
              "shouldPersist": false,
              "streamName": "countStream"
            }
          ]
        }
        """)
        SDKInstance.shared.resetForTesting()
        try await Digia.initialize(
            DigiaConfig(
                apiKey: "proj_123",
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: configPath,
                    functionsPath: "unused"
                )
            )
        )

        await #expect(throws: AppStateStoreError.self) {
            let action = SetAppStateAction(
                disableActionIf: nil,
                data: ["stateKey": .string("missing"), "value": .int(1)]
            )
            try await SetAppStateProcessor().execute(action: action, context: context())
        }

        await #expect(throws: AppStateStoreError.self) {
            let action = SetAppStateAction(
                disableActionIf: nil,
                data: ["stateKey": .string("count"), "value": .string("not-a-number")]
            )
            try await SetAppStateProcessor().execute(action: action, context: context())
        }
    }

    @Test("setAppState supports batch updates list and continues on per-update errors")
    func setAppStateBatchUpdatesContinueOnErrors() async throws {
        let configPath = try makeTempConfigFile("""
        {
          "appSettings": { "initialRoute": "home" },
          "pages": { "home": { "uid": "home" } },
          "rest": {},
          "theme": { "colors": { "light": {} } },
          "appState": [
            { "name": "count", "type": "number", "value": 1, "shouldPersist": false, "streamName": "countStream" },
            { "name": "theme", "type": "string", "value": "light", "shouldPersist": false, "streamName": "themeStream" }
          ]
        }
        """)
        SDKInstance.shared.resetForTesting()
        try await Digia.initialize(
            DigiaConfig(
                apiKey: "proj_123",
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: configPath,
                    functionsPath: "unused"
                )
            )
        )

        let action = SetAppStateAction(
            disableActionIf: nil,
            data: [
                "updates": .array([
                    .object(["stateName": .string("count"), "newValue": .int(2)]),
                    .object(["stateName": .string("missing"), "newValue": .string("x")]),
                ]),
            ]
        )

        try await SetAppStateProcessor().execute(action: action, context: context())
        #expect(SDKInstance.shared.appState["count"] == .int(2))
        #expect(SDKInstance.shared.appState["theme"] == .string("light"))
    }

    @Test("setAppState evaluates expression-like newValue in batch updates")
    func setAppStateBatchUpdateEvaluatesExpression() async throws {
        let configPath = try makeTempConfigFile("""
        {
          "appSettings": { "initialRoute": "home" },
          "pages": { "home": { "uid": "home" } },
          "rest": {},
          "theme": { "colors": { "light": {} } },
          "appState": [
            { "name": "count", "type": "number", "value": 1, "shouldPersist": false, "streamName": "countStream" }
          ]
        }
        """)
        SDKInstance.shared.resetForTesting()
        try await Digia.initialize(
            DigiaConfig(
                apiKey: "proj_123",
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: configPath,
                    functionsPath: "unused"
                )
            )
        )

        let action = SetAppStateAction(
            disableActionIf: nil,
            data: [
                "updates": .array([
                    .object(["stateName": .string("count"), "newValue": .string("${1 + 1}")]),
                ]),
            ]
        )

        try await SetAppStateProcessor().execute(action: action, context: context())
        #expect(SDKInstance.shared.appState["count"] == .int(2))
    }
}
