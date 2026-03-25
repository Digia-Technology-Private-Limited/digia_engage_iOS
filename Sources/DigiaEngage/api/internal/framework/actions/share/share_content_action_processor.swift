import Foundation
import UIKit

struct ShareContentAction: Sendable {
    let actionType: ActionType = .shareContent
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct ShareContentProcessor {
    let processorType: ActionType = .shareContent

    func execute(action: ShareContentAction, context: ActionProcessorContext) async throws {
        guard let message = ExpressionUtil.evaluateNestedExpressionsToAny(action.data["message"], in: context.scopeContext) as? String,
              !message.isEmpty else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }
        let subject = ExpressionUtil.evaluateNestedExpressionsToAny(action.data["subject"], in: context.scopeContext) as? String
        SDKInstance.shared.share(message: message, subject: subject)
        // UIActivityViewController requires an active scene + presenting controller; skip when the SDK
        // is invoked without a host UI (for example, during unit tests).
        if NSClassFromString("XCTestCase") == nil, ViewControllerUtil.topViewController() != nil {
            let controller = UIActivityViewController(activityItems: [message], applicationActivities: nil)
            controller.setValue(subject, forKey: "subject")
            ViewControllerUtil.present(controller)
        }
    }
}
