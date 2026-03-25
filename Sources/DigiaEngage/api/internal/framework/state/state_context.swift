import Foundation

final class StateContext: ObservableObject {
    let namespace: String?
    private let parent: StateContext?
    // Intentionally NOT @Published.
    // We want `setValues(..., notify: false)` to mutate state without triggering SwiftUI updates.
    // Rebuilds should only happen via explicit `objectWillChange.send()` (notify=true or rebuildState).
    private(set) var stateVariables: [String: JSONValue]

    init(namespace: String?, initialState: [String: JSONValue], parent: StateContext? = nil) {
        self.namespace = namespace
        self.stateVariables = initialState
        self.parent = parent
    }

    func getValue(_ key: String) -> JSONValue? {
        if let value = stateVariables[key] {
            return value
        }
        return parent?.getValue(key)
    }

    func hasKey(_ key: String) -> Bool {
        stateVariables[key] != nil
    }

    func setValues(_ updates: [String: JSONValue], notify: Bool) {
        guard !updates.isEmpty else { return }
        var changed = false
        for (key, value) in updates where stateVariables[key] != nil {
            if stateVariables[key] != value {
                stateVariables[key] = value
                changed = true
            }
        }
        if notify, changed {
            objectWillChange.send()
        }
    }

    func triggerListeners() {
        objectWillChange.send()
    }

    func findAncestorContext(_ targetNamespace: String) -> StateContext? {
        if namespace == targetNamespace {
            return self
        }
        return parent?.findAncestorContext(targetNamespace)
    }
}
