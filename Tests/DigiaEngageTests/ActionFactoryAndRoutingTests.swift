import Foundation
@testable import DigiaEngage
import Testing

@MainActor
@Suite("ActionFactory and Processor Routing")
struct ActionFactoryAndRoutingTests {
    @Test("maps hideBottomSheet and dismissDialog to dedicated actions")
    func mapsAliasesToDedicatedActions() throws {
        let hideStep = try decodeStep(type: "Action.hideBottomSheet")
        let dismissStep = try decodeStep(type: "Action.dismissDialog")

        let hideAction = try ActionFactory.makeAction(from: hideStep)
        let dismissAction = try ActionFactory.makeAction(from: dismissStep)

        #expect(hideAction.actionType == .hideBottomSheet)
        #expect(dismissAction.actionType == .dismissDialog)
    }

    @Test("routes showToast action to ShowToast processor")
    func routesShowToastProcessor() throws {
        let step = try decodeStep(
            type: "Action.showToast",
            data: ["message": .string("Hello")]
        )
        let action = try ActionFactory.makeAction(from: step)
        #expect(ActionProcessorFactory.processorType(for: action) == .showToast)
    }

    @Test("routes callRestApi action to CallRestApi processor")
    func routesCallRestApiProcessor() throws {
        let step = try decodeStep(
            type: "Action.callRestApi",
            data: ["dataSource": .object(["id": .string("get_user")])]
        )
        let action = try ActionFactory.makeAction(from: step)
        #expect(ActionProcessorFactory.processorType(for: action) == .callRestApi)
    }

    private func decodeStep(type: String, data: [String: JSONValue]? = nil) throws -> ActionStep {
        let step = ActionStep(type: type, data: data, disableActionIf: nil)
        let encoded = try JSONEncoder().encode(step)
        return try JSONDecoder().decode(ActionStep.self, from: encoded)
    }
}
