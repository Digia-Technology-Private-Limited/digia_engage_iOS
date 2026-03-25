import SwiftUI

@MainActor
struct InternalStreamBuilder<Content: View>: View {
    let controller: DigiaValueStream
    let initialData: Any?
    let onSuccess: ((Any?) -> Void)?
    let onError: ((Error?) -> Void)?
    let content: (_ data: Any?, _ state: String, _ error: Error?) -> Content

    @State private var value: Any?
    @State private var streamState: String = "loading"
    @State private var streamError: Error?
    @State private var token: UUID?

    var body: some View {
        content(value, streamState, streamError)
            .onAppear {
                value = initialData ?? controller.currentValue
                streamState = value == nil ? "loading" : "listening"
                token = controller.subscribe { nextValue in
                    let emitted = ExpressionUtil.jsonValue(from: nextValue).anyValue
                    DispatchQueue.main.async {
                        value = emitted
                        streamState = "listening"
                        streamError = nil
                        onSuccess?(emitted)
                    }
                }
            }
            .onDisappear {
                if let token {
                    controller.unsubscribe(token)
                }
                token = nil
            }
    }
}
