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

        let waitForResult = (action.data["waitForResult"]?.deepEvaluate(in: context.scopeContext) as? Bool) ?? false

        let onResultFlow = action.data["onResult"]?.asActionFlow()
        let args = action.data["args"]?.objectValue ?? [:]
        let style = action.data["style"]?.objectValue ?? [:]

        let resources = ResourceProvider(
            fontFactory: SDKInstance.shared.fontFactory,
            appConfigStore: context.appConfig
        )

        let barrierColorStr = style["barrierColor"]?.deepEvaluate(in: context.scopeContext) as? String
        let barrierColor: Color = barrierColorStr.flatMap { resources.getColor($0) }
            ?? Color.black.opacity(0.54)

        let bgColorStr = style["bgColor"]?.deepEvaluate(in: context.scopeContext) as? String
        let sheetBackgroundColor = bgColorStr.flatMap { resources.getColor($0) }

        let maxHeightRatio = To.toDouble(style["maxHeight"]?.deepEvaluate(in: context.scopeContext)) ?? (9.0 / 16.0)
        let useSafeArea = (style["useSafeArea"]?.deepEvaluate(in: context.scopeContext) as? Bool) ?? true
        let showDragHandle = (style["showDragHandle"]?.deepEvaluate(in: context.scopeContext) as? Bool) ?? false
        let borderStyleStr = style["borderStyle"]?.deepEvaluate(in: context.scopeContext) as? String
        let borderColorStr = style["borderColor"]?.deepEvaluate(in: context.scopeContext) as? String
        let borderColor: Color? = borderColorStr.flatMap { resources.getColor($0) }
        let rawBorderWidth = style["borderWidth"]?.deepEvaluate(in: context.scopeContext)
        let borderWidth = To.toDouble(rawBorderWidth).map { CGFloat($0) }
        let cornerRadius = WidgetUtil.resolveCornerRadius(style["borderRadius"], scopeContext: context.scopeContext)
            .map { radius in
                CornerRadiusProps(
                    topLeft: radius.topLeft,
                    topRight: radius.topRight,
                    bottomRight: 0,
                    bottomLeft: 0
                )
            }

        let presentation = DigiaBottomSheetPresentation(
            view: DigiaViewPresentation(
                viewID: viewID,
                title: viewData["title"]?.stringValue ?? action.data["title"]?.stringValue,
                text: viewData["text"]?.stringValue ?? action.data["message"]?.stringValue,
                args: args
            ),
            barrierColor: barrierColor,
            maxHeight: maxHeightRatio,
            sheetBackgroundColor: sheetBackgroundColor,
            cornerRadius: cornerRadius,
            borderColor: borderColor,
            borderWidth: borderWidth,
            borderStyle: borderStyleStr,
            useSafeArea: useSafeArea,
            showDragHandle: showDragHandle
        )
        let overlayController = SDKInstance.shared.controller
        let transition = BottomSheetTransitionModel()
        overlayController.bottomSheetTransition = transition

        let rendersInHost = SDKInstance.shared.isHostMounted
        overlayController.showBottomSheet(presentation, rendersInHost: rendersInHost)

        if !rendersInHost {
            let root = NavigationUtil.presentBottomSheetContent(
                presentation: presentation,
                overlayController: overlayController,
                transition: transition,
                dismissesPresentedViewController: true
            ) {
                DigiaPresentationView(presentation: presentation.view)
            }

            let host = UIHostingController(rootView: root)
            host.view.backgroundColor = .clear
            host.modalPresentationStyle = .overFullScreen
            ViewControllerUtil.present(host, animated: false)
        }

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
