import Combine
import Foundation
@testable import DigiaEngage
import Testing

@MainActor
@Suite("State and Event Actions", .serialized)
struct StateAndEventActionTests {
    @Test("setAppState stores the key-value pair in runtime state")
    func setAppStateStoresValue() async throws {
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
              "value": "light",
              "shouldPersist": false,
              "streamName": "themeStream"
            }
          ]
        }
        """)
        try await Digia.initialize(
            DigiaConfig(
                apiKey: "prod_123",
                flavor: .release(
                    initStrategy: .localFirst,
                    appConfigPath: configPath,
                    functionsPath: "unused"
                )
            )
        )
        let action = SetAppStateAction(
            disableActionIf: nil,
            data: ["stateKey": .string("theme"), "value": .string("dark")]
        )
        try await SetAppStateProcessor().execute(action: action, context: context())
        #expect(SDKInstance.shared.appState["theme"] == .string("dark"))
    }

    @Test("setState and rebuildState update local mutable view state")
    func setStateAndRebuildStateWork() async throws {
        let store = StateContext(namespace: "actiontests-X5o9Xo", initialState: ["myState": .string("Initial State")])

        let setAction = SetStateAction(
            disableActionIf: nil,
            data: [
                "updates": .array([
                    .object(["stateName": .string("myState"), "newValue": .string("Updated State")])
                ]),
                "rebuild": .bool(false),
            ]
        )
        try await SetStateProcessor().execute(action: setAction, context: context(localStateStore: store))
        #expect(store.stateVariables["myState"] == .string("Updated State"))

        var didNotify = false
        let cancellable = store.objectWillChange.sink { _ in didNotify = true }
        defer { cancellable.cancel() }

        try await RebuildStateProcessor().execute(
            action: RebuildStateAction(disableActionIf: nil, data: [:]),
            context: context(localStateStore: store)
        )
        #expect(didNotify)
    }

    @Test("fireEvent accepts events array when active payload exists")
    func fireEventAcceptsEventsArray() async throws {
        SDKInstance.shared.resetForTesting()
        let payload = InAppPayload(id: "campaign", content: InAppPayloadContent(type: "dialog"))
        SDKInstance.shared.onCampaignTriggered(payload)
        let recorder = EventRecorder()
        SDKInstance.shared.controller.onEvent = { event, _ in
            recorder.values.append(event)
        }
        try await FireEventProcessor().execute(
            action: FireEventAction(disableActionIf: nil, data: ["events": .array([.object(["name": .string("test")])])]),
            context: context()
        )
        #expect(recorder.values.count == 1)
    }

    private func context(appConfig: AppConfigStore = AppConfigStore(), localStateStore: StateContext? = nil) -> ActionProcessorContext {
        ActionProcessorContext(appConfig: appConfig, localStateStore: localStateStore)
    }
}

private final class EventRecorder: @unchecked Sendable {
    var values: [DigiaExperienceEvent] = []
}
