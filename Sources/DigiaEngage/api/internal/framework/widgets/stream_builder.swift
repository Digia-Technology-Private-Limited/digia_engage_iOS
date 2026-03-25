import SwiftUI

@MainActor
final class VWStreamBuilder: VirtualStatelessWidget<StreamBuilderProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let controller = payload.evalAny(props.controller) as? DigiaValueStream else {
            return empty()
        }

        let initialData = payload.evalAny(props.initialData)
        return AnyView(
            InternalStreamBuilder(
                controller: controller,
                initialData: initialData,
                onSuccess: { data in
                    let context = self.makeContext(data: data, state: "listening", error: nil)
                    let chained = payload.copyWithChainedContext(context)
                    chained.executeAction(self.props.onSuccess, triggerType: "onSuccess", scopeContext: chained.scopeContext)
                },
                onError: { error in
                    let context = self.makeContext(data: nil, state: "error", error: error)
                    let chained = payload.copyWithChainedContext(context)
                    chained.executeAction(self.props.onError, triggerType: "onError", scopeContext: chained.scopeContext)
                },
                content: { data, state, error in
                    let context = self.makeContext(data: data, state: state, error: error)
                    let chained = payload.copyWithChainedContext(context)
                    return self.child?.toWidget(chained) ?? self.empty()
                }
            )
        )
    }

    private func makeContext(data: Any?, state: String, error: Error?) -> any ScopeContext {
        var streamObject: [String: Any?] = [
            "streamState": state,
            "streamValue": data,
        ]
        if let error {
            streamObject["error"] = String(describing: error)
        }
        if let refName {
            streamObject[refName] = streamObject
        }
        return BasicExprContext(variables: streamObject)
    }
}
