import Foundation
import SwiftUI
import UIKit

struct ShowBottomSheetAction: Sendable {
    let actionType: ActionType = .showBottomSheet
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct ShowBottomSheetProcessor {
    let processorType: ActionType = .showBottomSheet

    func execute(action: ShowBottomSheetAction, context: ActionProcessorContext) async throws {
        let viewData = action.data["viewData"]?.objectValue ?? [:]
        let viewID = viewData["id"]?.stringValue
            ?? action.data["componentId"]?.stringValue
            ?? action.data["pageId"]?.stringValue
        guard let viewID else { throw ActionExecutionError.unsupportedContext(processorType) }

        let waitForResult = (ExpressionUtil.evaluateNestedExpressionsToAny(
            action.data["waitForResult"], in: context.scopeContext
        ) as? Bool) ?? false

        let onResultFlow = action.data["onResult"]?.asActionFlow()
        let args = action.data["args"]?.objectValue ?? [:]

        // Style properties — mirrors Flutter's action.style
        let style = action.data["style"]?.objectValue ?? [:]

        let barrierColorStr = ExpressionUtil.evaluateNestedExpressionsToAny(
            style["barrierColor"], in: context.scopeContext
        ) as? String
        let barrierColor: Color = barrierColorStr.flatMap { ColorUtil.fromString($0) }
            ?? Color.black.opacity(0.54)  // Flutter default: Colors.black54

        let maxHeightRatio = (ExpressionUtil.evaluateNestedExpressionsToAny(
            style["maxHeight"], in: context.scopeContext
        ) as? Double) ?? 1.0

        let borderColorStr = ExpressionUtil.evaluateNestedExpressionsToAny(
            style["borderColor"], in: context.scopeContext
        ) as? String
        let borderColor: Color? = borderColorStr.flatMap { ColorUtil.fromString($0) }
        let borderWidth = (ExpressionUtil.evaluateNestedExpressionsToAny(
            style["borderWidth"], in: context.scopeContext
        ) as? Double).map { CGFloat($0) }

        let presentation = DigiaBottomSheetPresentation(
            view: DigiaViewPresentation(
                viewID: viewID,
                title: viewData["title"]?.stringValue ?? action.data["title"]?.stringValue,
                text: viewData["text"]?.stringValue ?? action.data["message"]?.stringValue,
                args: args
            ),
            barrierColor: barrierColor,
            maxHeight: maxHeightRatio,
            borderColor: borderColor,
            borderWidth: borderWidth
        )
        SDKInstance.shared.controller.showBottomSheet(presentation)

        let overlayController = SDKInstance.shared.controller

        // Layout mirrors Flutter's presentBottomSheet:
        //   Column(mainAxisSize: MainAxisSize.min) → VStack + Spacer with lower priority
        //   so the sheet wraps its content instead of expanding to fill the screen.
        let maxAllowedHeight = UIScreen.main.bounds.height * presentation.maxHeight
        let root = ZStack(alignment: .bottom) {
            // Barrier overlay — tapping anywhere outside the sheet dismisses it
            presentation.barrierColor
                .ignoresSafeArea()
                .onTapGesture {
                    DispatchQueue.main.async {
                        ViewControllerUtil.dismissPresented {
                            overlayController.dismissBottomSheet()
                        }
                    }
                }

            VStack(spacing: 0) {
                Spacer()
                    .layoutPriority(-1)

                DigiaPresentationView(presentation: presentation.view)
                    .frame(maxWidth: .infinity, maxHeight: maxAllowedHeight)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 16,
                        style: .continuous
                    ))
                    .overlay(alignment: .top) {
                        if let borderColor = presentation.borderColor, let borderWidth = presentation.borderWidth, borderWidth > 0 {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 16,
                                style: .continuous
                            )
                            .stroke(borderColor, lineWidth: borderWidth)
                        }
                    }
            }
            .ignoresSafeArea(edges: .bottom)
        }

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.modalPresentationStyle = .overFullScreen
        ViewControllerUtil.present(host)

        if waitForResult, onResultFlow != nil {
            let result = await withCheckedContinuation { (continuation: CheckedContinuation<JSONValue?, Never>) in
                overlayController.onBottomSheetDismissed = { value in
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
