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

        // Style properties — mirrors Flutter's action.style
        let style = action.data["style"]?.objectValue ?? [:]

        let barrierColorStr = ExpressionUtil.evaluateNestedExpressionsToAny(
            style["barrierColor"], in: context.scopeContext
        ) as? String
        let barrierColor: Color = barrierColorStr.flatMap { ColorUtil.fromString($0) }
            ?? Color.black.opacity(0.54)  // Flutter default: Colors.black54

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
        SDKInstance.shared.controller.showDialog(presentation)

        let overlayController = SDKInstance.shared.controller

        // Layout mirrors Flutter's Dialog(child: ...):
        //   Dialog wraps content at intrinsic size, centered on screen.
        //   fixedSize(vertical: true) prevents the ZStack from offering full screen
        //   height to the content, matching Flutter's intrinsic-height behavior.
        let maxDialogWidth = min(UIScreen.main.bounds.width - 48, 560.0)

        let root = ZStack {
            if presentation.barrierDismissible {
                presentation.barrierColor
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
                presentation.barrierColor
                    .ignoresSafeArea()
            }

            DigiaPresentationView(presentation: presentation.view)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 280, maxWidth: maxDialogWidth)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(24)
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
