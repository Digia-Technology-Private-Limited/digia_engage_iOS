import SwiftUI

// MARK: - DigiaLabelRegistry (internal)

/// Stores the on-screen frame for each labeled view so tooltip and coachmark actions
/// can position themselves relative to the tagged element.
///
/// Conforms to ObservableObject so SwiftUI views (e.g. TooltipBubble) can
/// react when a label's frame changes — e.g. after a scroll or rotation.
@MainActor
public final class DigiaLabelRegistry: ObservableObject {
    public static let shared = DigiaLabelRegistry()
    private init() {}

    @Published private(set) var frames: [String: CGRect] = [:]

    public func register(_ key: String, frame: CGRect) {
        guard frames[key] != frame else { return } // skip unchanged — prevents redraw loops
        frames[key] = frame
    }

    func frame(for key: String) -> CGRect? {
        frames[key]
    }
}

// MARK: - Preference key (private)
private struct DigiaLabelPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - Public modifier

public extension View {
    /// Tags this view so tooltip and coachmark actions can position themselves relative to it.
    ///
    /// Usage:
    /// ```swift
    /// Button("Claim offer") { ... }
    ///     .digiaLabel("claim_btn")
    /// ```
    ///
    /// Then in server-side action JSON:
    /// ```json
    /// { "type": "Action.showTooltip", "componentId": "bubble", "targetKey": "claim_btn" }
    /// ```
    func digiaLabel(_ key: String) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: DigiaLabelPreferenceKey.self,
                        value: [key: geo.frame(in: .named(DigiaCoordinateSpaceName.overlay))]
                    )
            }
        )
        .onPreferenceChange(DigiaLabelPreferenceKey.self) { @MainActor frames in
            for (k, rect) in frames {
                DigiaLabelRegistry.shared.register(k, frame: rect)
            }
        }
    }
}
