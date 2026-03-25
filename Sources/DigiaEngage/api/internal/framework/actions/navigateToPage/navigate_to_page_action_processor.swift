import Foundation

struct NavigateToPageAction: Sendable {
    let actionType: ActionType = .navigateToPage
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct NavigateToPageProcessor {
    let processorType: ActionType = .navigateToPage

    func execute(action: NavigateToPageAction, context: ActionProcessorContext) async throws {
        let pageData = action.data.object("pageData")
        let pageID = pageData?.string("id") ?? action.data.string("pageId") ?? action.data.string("id")
        guard let pageID, context.appConfig.page(pageID) != nil else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }

        // Resolve args to pass to the target page.
        let rawArgs = action.data["args"]?.objectValue ?? pageData?.object("args") ?? [:]
        let args = rawArgs.mapValues { ExpressionUtil.evaluateNestedExpressions($0, in: context.scopeContext) }

        let removePrevious = (ExpressionUtil.evaluateNestedExpressionsToAny(
            action.data["shouldRemovePreviousScreensInStack"], in: context.scopeContext
        ) as? Bool) ?? false

        let waitForResult = (ExpressionUtil.evaluateNestedExpressionsToAny(
            action.data["waitForResult"], in: context.scopeContext
        ) as? Bool) ?? false

        let onResultFlow = action.data["onResult"]?.asActionFlow()

        if removePrevious {
            SDKInstance.shared.navigationController.replaceStack(with: pageID, args: args)
        } else if waitForResult, onResultFlow != nil {
            let result = await SDKInstance.shared.navigationController.push(
                pageID, args: args, waitingForResult: true
            )
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
        } else {
            SDKInstance.shared.navigationController.push(pageID, args: args)
        }
    }
}
