import SwiftUI

private struct MarqueeWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MarqueeHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

@MainActor
struct InternalMarquee<Content: View>: View {
    let duration: Double
    let gap: CGFloat
    let content: Content

    @State private var contentWidth: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    init(duration: Double = 11, gap: CGFloat = 100, @ViewBuilder content: () -> Content) {
        self.duration = duration
        self.gap = gap
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                if contentWidth > proxy.size.width {
                    HStack(spacing: gap) {
                        content.fixedSize(horizontal: true, vertical: false)
                        content.fixedSize(horizontal: true, vertical: false)
                    }
                    .offset(x: offset)
                    .onAppear {
                        containerWidth = proxy.size.width
                        startAnimationIfNeeded()
                    }
                } else {
                    content
                }
            }
            .clipped()
            .onAppear {
                containerWidth = proxy.size.width
                startAnimationIfNeeded()
            }
        }
        .frame(height: max(contentHeight, 1))
        .background(
            content
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: MarqueeWidthKey.self, value: proxy.size.width)
                            .preference(key: MarqueeHeightKey.self, value: proxy.size.height)
                    }
                )
                .hidden()
        )
        .onPreferenceChange(MarqueeWidthKey.self) { width in
            contentWidth = width
            startAnimationIfNeeded()
        }
        .onPreferenceChange(MarqueeHeightKey.self) { height in
            contentHeight = height
        }
    }

    private func startAnimationIfNeeded() {
        guard contentWidth > 0, containerWidth > 0, contentWidth > containerWidth else {
            offset = 0
            return
        }
        offset = 0
        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -(contentWidth + gap)
        }
    }
}
