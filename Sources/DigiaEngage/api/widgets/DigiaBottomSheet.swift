import SwiftUI

/// Presentation chrome for a Digia bottom sheet, decoupled from any one feature
/// (nudge, survey, …). Each surface maps its own config onto this.
struct DigiaBottomSheetConfig {
    var cornerRadius: CGFloat = 18
    var background: Color = .white
    /// Show the grabber pill at the top of the sheet.
    var showHandle: Bool = true
    /// Allow swipe-down / interactive dismissal.
    var allowInteractiveDismiss: Bool = true
    /// Sheet-height ceiling as a fraction of the screen height. Content shorter
    /// than this hugs its natural height (no dead space); taller content scrolls
    /// within the ceiling.
    var heightCapFraction: CGFloat = 0.85
}

/// Carries the content's natural height up so the native sheet's detent can size
/// *to its content* (capped) instead of snapping to `.medium`/`.large` and
/// leaving a blank band below the content.
private struct DigiaSheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// The single bottom-sheet surface every Digia feature renders through.
///
/// It owns the things a "good" sheet needs and that SwiftUI's native sheet gives
/// us for free — scrim, drag-to-dismiss, safe-area handling, corner radius — and
/// adds the one piece SwiftUI lacks: a content-fitting detent. It measures the
/// content and pins the detent to `min(contentHeight + homeIndicatorInset, cap)`,
/// so the sheet hugs its content and never leaves the empty space below it.
///
/// Drive it from a `.sheet(item:)` / `.sheet(isPresented:)` on a view that lives
/// in the hierarchy. Content that can exceed the cap should set `scrollable:
/// true` (the default) so this wraps it in a scroll view; content that manages
/// its own scrolling passes `scrollable: false`.
struct DigiaBottomSheet<Content: View>: View {
    let config: DigiaBottomSheetConfig
    var scrollable: Bool = true
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0

    /// The native `.height` detent measures from the screen's bottom edge (behind
    /// the home indicator), so a little clearance is added below the content. This
    /// is intentionally small — adding the *full* safe-area inset (~34pt) leaves a
    /// tall dead band under short content. Callers already pad their content, so
    /// this only has to lift the last row clear of the indicator.
    private let bottomClearance: CGFloat = 8

    private var detents: Set<PresentationDetent> {
        let cap = UIScreen.main.bounds.height * config.heightCapFraction
        guard contentHeight > 0 else { return [.medium] }
        return [.height(min(contentHeight + bottomClearance, cap))]
    }

    private var measuredContent: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DigiaSheetHeightKey.self,
                        value: proxy.size.height
                    )
                }
            )
    }

    var body: some View {
        Group {
            if scrollable {
                ScrollView { measuredContent }
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                // Caller manages its own scrolling; just pin to the top.
                measuredContent
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onPreferenceChange(DigiaSheetHeightKey.self) { contentHeight = $0 }
        .presentationDetents(detents)
        .presentationDragIndicator(config.showHandle ? .visible : .hidden)
        .presentationCornerRadius(config.cornerRadius)
        .presentationBackground(config.background)
        .interactiveDismissDisabled(!config.allowInteractiveDismiss)
    }
}
