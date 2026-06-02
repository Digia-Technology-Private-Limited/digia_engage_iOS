import Foundation
import SwiftUI
import UIKit

struct ShowDialogAction: Sendable {
    let actionType: ActionType = .showDialog
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct ShowDialogProcessor {
    let processorType: ActionType = .showDialog

    func execute(action: ShowDialogAction, context: ActionProcessorContext) async throws {
        let viewData = action.data.object("viewData") ?? [:]
        let viewID = viewData.string("id") ?? action.data.string("componentId") ?? action.data.string("pageId")
        guard let viewID else { throw ActionExecutionError.unsupportedContext(processorType) }

        let barrierDismissible = (action.data["barrierDismissible"]?.deepEvaluate(in: context.scopeContext) as? Bool) ?? true

        let waitForResult = (action.data["waitForResult"]?.deepEvaluate(in: context.scopeContext) as? Bool) ?? false

        let onResultFlow = action.data["onResult"]?.asActionFlow()
        let args = action.data["args"]?.objectValue ?? [:]

        let style = action.data["style"]?.objectValue ?? [:]
        let resources = ResourceProvider(
            fontFactory: SDKInstance.shared.fontFactory,
            appConfigStore: context.appConfig
        )
        let barrierColorStr =
            (action.data["barrierColor"]?.deepEvaluate(in: context.scopeContext) as? String)
            ?? (style["barrierColor"]?.deepEvaluate(in: context.scopeContext) as? String)
        let barrierColor: Color = barrierColorStr.flatMap { resources.getColor($0) }
            ?? Color.black.opacity(0.54)

        let presentation = DigiaDialogPresentation(
            view: DigiaViewPresentation(
                viewID: viewID,
                title: viewData.string("title") ?? action.data.string("title"),
                text: viewData.string("text") ?? action.data.string("message"),
                args: args
            ),
            barrierDismissible: barrierDismissible,
            barrierColor: barrierColor
        )
        let overlayController = SDKInstance.shared.controller
        overlayController.showDialog(presentation)

        let root = NavigationUtil.presentDialogContent(
            presentation: presentation,
            overlayController: overlayController,
            dismissesPresentedViewController: true
        ) {
            DigiaPresentationView(presentation: presentation.view)
        }

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        ViewControllerUtil.present(host, animated: false)

        if waitForResult, onResultFlow != nil {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<JSONValue?, Never>) in
                overlayController.onDialogDismissed = { value in
                    continuation.resume(returning: value)
                }
            }
            let resultContext = BasicExprContext(variables: ["result": result?.anyValue ?? NSNull()])
            if let scopeContext = context.scopeContext {
                resultContext.addContextAtTail(scopeContext)
            }
            await context.actionExecutor.executeNow(
                onResultFlow,
                appConfig: context.appConfig,
                scopeContext: resultContext,
                triggerType: "onResult",
                localStateStore: context.localStateStore
            )
        }
    }
}
