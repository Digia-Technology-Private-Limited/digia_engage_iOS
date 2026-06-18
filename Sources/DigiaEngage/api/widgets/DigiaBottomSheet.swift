import SwiftUI

struct DigiaBottomSheetConfig {
    var cornerRadius: CGFloat = 18
    var background: Color = .white
    var showHandle: Bool = true
    var allowInteractiveDismiss: Bool = true
    var heightCapFraction: CGFloat = 0.85
}

struct DigiaBottomSheet<Content: View>: View {
    let config: DigiaBottomSheetConfig
    var scrollable: Bool = true
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0

    private var detent: PresentationDetent {
        guard contentHeight > 0 else { return .large }
        let safeBottom = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
        let cap = UIScreen.main.bounds.height * config.heightCapFraction
        return .height(min(contentHeight + safeBottom, cap))
    }

    private var measuredContent: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: SheetHeightKey.self, value: geo.size.height)
                }
            )
    }

    var body: some View {
        Group {
            if scrollable {
                ScrollView { measuredContent }
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                measuredContent
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .onPreferenceChange(SheetHeightKey.self) { contentHeight = $0 }
        .presentationDetents([detent])
        .presentationDragIndicator(config.showHandle ? .visible : .hidden)
        .presentationCornerRadius(config.cornerRadius)
        .presentationBackground(config.background)
        .interactiveDismissDisabled(!config.allowInteractiveDismiss)
    }
}

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
