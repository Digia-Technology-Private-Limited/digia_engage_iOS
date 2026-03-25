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

        let barrierDismissible = (ExpressionUtil.evaluateNestedExpressionsToAny(
            action.data["barrierDismissible"], in: context.scopeContext
        ) as? Bool) ?? true

        let waitForResult = (ExpressionUtil.evaluateNestedExpressionsToAny(
            action.data["waitForResult"], in: context.scopeContext
        ) as? Bool) ?? false

        let onResultFlow = action.data["onResult"]?.asActionFlow()
        let args: [String: JSONValue]
        if case let .object(value)? = action.data["args"] {
            args = value
        } else {
            args = [:]
        }

        let presentation = DigiaDialogPresentation(
            view: DigiaViewPresentation(
                viewID: viewID,
                title: viewData.string("title") ?? action.data.string("title"),
                text: viewData.string("text") ?? action.data.string("message"),
                args: args
            ),
            barrierDismissible: barrierDismissible
        )
        SDKInstance.shared.controller.showDialog(presentation)

        let overlayController = SDKInstance.shared.controller
        let root = ZStack {
            if barrierDismissible {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        DispatchQueue.main.async {
                            ViewControllerUtil.dismissPresented {
                                overlayController.dismissDialog()
                            }
                        }
                    }
            } else {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
            }
            DigiaPresentationView(presentation: presentation.view)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        ViewControllerUtil.present(host)

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
