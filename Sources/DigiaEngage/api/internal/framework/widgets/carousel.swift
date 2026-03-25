import SwiftUI

@MainActor
final class VWCarousel: VirtualStatelessWidget<CarouselProps> {
    override func render(_ payload: RenderPayload) -> AnyView {
        guard let child = child else { return empty() }

        let repeatedItems = resolveDataSource(payload: payload)
        let pages: [AnyView]
        if let repeatedItems {
            pages = repeatedItems.enumerated().map { index, item in
                child.toWidget(payload.copyWithChainedContext(createExprContext(item, index: index)))
            }
        } else {
            pages = children?.map { $0.toWidget(payload) } ?? [child.toWidget(payload)]
        }

        guard !pages.isEmpty else { return empty() }

        return AnyView(
            DigiaCarouselView(
                pages: pages,
                width: payload.eval(props.width).map { CGFloat($0) },
                height: payload.eval(props.height).map { CGFloat($0) },
                direction: props.direction,
                aspectRatio: props.aspectRatio,
                initialPage: payload.eval(props.initialPage) ?? 0,
                autoPlay: props.autoPlay ?? false,
                autoPlayInterval: props.autoPlayInterval ?? 1600,
                animationDuration: props.animationDuration ?? 800,
                reverseScroll: props.reverseScroll ?? false,
                infiniteScroll: props.infiniteScroll ?? false,
                viewportFraction: props.viewportFraction ?? 0.8,
                enlargeCenterPage: props.enlargeCenterPage ?? false,
                enlargeFactor: props.enlargeFactor ?? 0.3,
                pageSnapping: props.pageSnapping ?? true,
                showIndicator: props.showIndicator ?? false,
                dotHeight: props.dotHeight ?? 8,
                dotWidth: props.dotWidth ?? 8,
                padEnds: props.padEnds ?? true,
                spacing: props.spacing ?? 16,
                offset: props.offset ?? 16,
                dotColor: payload.evalColor(props.dotColor) ?? .gray,
                activeDotColor: payload.evalColor(props.activeDotColor) ?? .indigo,
                indicatorEffectType: props.indicatorEffectType ?? "slide",
                onChanged: { index in
                    payload.executeAction(
                        self.props.onChanged,
                        triggerType: "onChanged",
                        scopeContext: BasicExprContext(variables: ["index": index])
                    )
                }
            )
        )
    }

    private func resolveDataSource(payload: RenderPayload) -> [Any]? {
        switch props.dataSource {
        case let .array(values):
            return values.map(\.anyValue)
        case let .string(value):
            guard ExpressionUtil.hasExpression(value),
                  let resolved = ExpressionUtil.evaluateAny(value, context: payload.scopeContext) else {
                return nil
            }
            return resolved as? [Any]
        default:
            return nil
        }
    }

    private func createExprContext(_ item: Any?, index: Int) -> any ScopeContext {
        let carouselObj: [String: Any?] = [
            "currentItem": item,
            "index": index,
        ]
        var variables = carouselObj
        if let refName {
            variables[refName] = carouselObj
        }
        return BasicExprContext(variables: variables)
    }
}

// MARK: - DigiaCarouselView

private struct DigiaCarouselView: View {
    let pages: [AnyView]
    let width: CGFloat?
    let height: CGFloat?
    let direction: String?
    let aspectRatio: Double?
    let initialPage: Int
    let autoPlay: Bool
    let autoPlayInterval: Int
    let animationDuration: Int
    let reverseScroll: Bool
    let infiniteScroll: Bool
    let viewportFraction: Double
    let enlargeCenterPage: Bool
    let enlargeFactor: Double
    let pageSnapping: Bool
    let showIndicator: Bool
    let dotHeight: Double
    let dotWidth: Double
    let padEnds: Bool
    let spacing: Double
    let offset: Double
    let dotColor: Color
    let activeDotColor: Color
    let indicatorEffectType: String
    let onChanged: (Int) -> Void

    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    // When infiniteScroll is on we wrap pages: [last, ...pages, first]
    private var displayPages: [AnyView] {
        guard infiniteScroll, pages.count > 1 else { return pages }
        var result: [AnyView] = []
        result.append(pages[pages.count - 1])
        result.append(contentsOf: pages)
        result.append(pages[0])
        return result
    }

    // Offset within displayPages that corresponds to real page 0
    private var phantomOffset: Int { infiniteScroll && pages.count > 1 ? 1 : 0 }

    private var pageCount: Int { displayPages.count }

    var body: some View {
        GeometryReader { geo in
            let cw = width ?? geo.size.width
            let ch = resolvedHeight(containerWidth: cw)
            let pageWidth = cw * viewportFraction
            let sideGap = padEnds ? (cw - pageWidth) / 2 : 0
            let axis = resolvedAxis
            let pageExtent = axis == .horizontal ? pageWidth : ch

            VStack(spacing: 0) {
                ZStack {
                    // Pages laid out in an HStack; we translate by drag + page offset
                    Group {
                        if axis == .horizontal {
                            HStack(spacing: 0) {
                                ForEach(Array(displayPages.enumerated()), id: \.offset) { idx, page in
                                    page
                                        .frame(width: pageWidth, height: ch)
                                        .scaleEffect(scaleFor(idx: idx, pageExtent: pageExtent))
                                        .animation(.easeInOut(duration: animDuration), value: currentPage)
                                        .animation(.interactiveSpring(), value: dragOffset)
                                        .clipped()
                                }
                            }
                            .frame(width: cw, alignment: .leading)
                            .offset(x: xOffset(pageWidth: pageWidth, sideGap: sideGap))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(displayPages.enumerated()), id: \.offset) { idx, page in
                                    page
                                        .frame(width: cw, height: ch)
                                        .scaleEffect(scaleFor(idx: idx, pageExtent: pageExtent))
                                        .animation(.easeInOut(duration: animDuration), value: currentPage)
                                        .animation(.interactiveSpring(), value: dragOffset)
                                        .clipped()
                                }
                            }
                            .frame(height: ch, alignment: .top)
                            .offset(y: yOffset(pageHeight: ch, sideGap: 0))
                        }
                    }
                    .animation(.easeInOut(duration: animDuration), value: currentPage)
                    .animation(.interactiveSpring(), value: dragOffset)
                    .modifier(DigiaDragGestureModifier(
                        onChanged: { value in
                            dragOffset = axis == .horizontal ? value.translation.width : value.translation.height
                        },
                        onEnded: { value in
                            let translation = axis == .horizontal ? value.translation.width : value.translation.height
                            let predicted = axis == .horizontal ? value.predictedEndTranslation.width : value.predictedEndTranslation.height
                            handleDragEnd(
                                translation: translation,
                                predictedEndTranslation: predicted,
                                pageExtent: pageExtent
                            )
                        }
                    ))
                }
                .frame(width: cw, height: ch)
                .clipped()
                .onAppear {
                    containerWidth = cw
                    containerHeight = ch
                    currentPage = phantomOffset + bounded(initialPage)
                }

                if showIndicator {
                    DigiaCarouselIndicator(
                        effectType: DigiaIndicatorEffectType(rawValue: indicatorEffectType) ?? .slide,
                        pageProgress: pageProgress(pageExtent: pageExtent),
                        count: pages.count,
                        dotSize: CGSize(width: dotWidth, height: dotHeight),
                        spacing: spacing,
                        offset: offset,
                        dotColor: dotColor,
                        activeDotColor: activeDotColor,
                        onDotTapped: { idx in jumpTo(realIndex: idx) }
                    )
                    .padding(.top, 8)
                }
            }
            .onReceive(Timer.publish(every: max(Double(autoPlayInterval) / 1000.0, 0.2),
                                    on: .main, in: .common).autoconnect()) { _ in
                guard autoPlay, pages.count > 1 else { return }
                let delta = reverseScroll ? -1 : 1

                if infiniteScroll {
                    let oldReal = realPage
                    withAnimation(.easeInOut(duration: animDuration)) {
                        currentPage += delta
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {
                        snapInfiniteLoop()
                        let newReal = realPage
                        if newReal != oldReal {
                            onChanged(newReal)
                        }
                    }
                } else {
                    let next = currentPage + delta
                    let clamped = min(max(next, 0), pages.count - 1)
                    guard clamped != currentPage else { return }
                    let oldReal = realPage
                    withAnimation(.easeInOut(duration: animDuration)) {
                        currentPage = clamped
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {
                        let newReal = realPage
                        if newReal != oldReal {
                            onChanged(newReal)
                        }
                    }
                }
            }
        }
        .frame(
            width: width,
            height: totalHeight(
                containerWidth: width ?? (containerWidth > 0 ? containerWidth : fallbackContainerWidth)
            )
        )
    }

    // MARK: - Helpers

    private var animDuration: Double { Double(animationDuration) / 1000.0 }

    private var fallbackContainerWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    var realPage: Int {
        guard infiniteScroll, pages.count > 1 else {
            return max(0, min(currentPage, pages.count - 1))
        }
        let adjusted = (currentPage - phantomOffset + pages.count * 100) % pages.count
        return adjusted
    }

    private var resolvedAxis: Axis {
        // Flutter uses Axis.horizontal / Axis.vertical; in JSON we carry "horizontal"/"vertical" string.
        // Default: horizontal.
        (direction ?? "horizontal").lowercased() == "vertical" ? .vertical : .horizontal
    }

    private func xOffset(pageWidth: CGFloat, sideGap: CGFloat) -> CGFloat {
        let effectiveDrag = reverseScroll ? -dragOffset : dragOffset
        let base = sideGap - CGFloat(currentPage) * pageWidth + effectiveDrag
        return base
    }

    private func yOffset(pageHeight: CGFloat, sideGap: CGFloat) -> CGFloat {
        let effectiveDrag = reverseScroll ? -dragOffset : dragOffset
        let base = sideGap - CGFloat(currentPage) * pageHeight + effectiveDrag
        return base
    }

    private func pageProgress(pageExtent: CGFloat) -> Double {
        guard pageExtent > 0 else { return Double(realPage) }
        let effectiveDrag = reverseScroll ? -dragOffset : dragOffset
        let raw = Double(currentPage) - Double(effectiveDrag / pageExtent)
        // Convert phantom-based index into real [0..count-1] space (as a continuous value).
        if infiniteScroll, pages.count > 1 {
            let shifted = raw - Double(phantomOffset)
            // wrap in positive space so mod works for negatives too
            let n = Double(pages.count)
            let wrapped = (shifted.truncatingRemainder(dividingBy: n) + n).truncatingRemainder(dividingBy: n)
            return wrapped
        }
        return min(max(raw, 0), Double(max(pages.count - 1, 0)))
    }

    private func scaleFor(idx: Int, pageExtent: CGFloat) -> CGFloat {
        guard enlargeCenterPage else { return 1.0 }
        let denom = max(pageExtent, 1)
        let effectiveDrag = reverseScroll ? -dragOffset : dragOffset
        let distance = abs(CGFloat(idx - currentPage) - effectiveDrag / denom)
        let scale = 1.0 - min(distance, 1.0) * enlargeFactor
        return max(scale, 0.5)
    }

    private func bounded(_ value: Int) -> Int {
        guard !pages.isEmpty else { return 0 }
        return min(max(value, 0), pages.count - 1)
    }

    private func handleDragEnd(translation: CGFloat, predictedEndTranslation: CGFloat, pageExtent: CGFloat) {
        guard pageExtent > 0 else {
            dragOffset = 0
            return
        }

        let effectiveTranslation = reverseScroll ? -translation : translation
        let effectivePredicted = reverseScroll ? -predictedEndTranslation : predictedEndTranslation

        let threshold = pageExtent * 0.3
        let velocity = effectivePredicted - effectiveTranslation

        let advance = effectiveTranslation < -threshold || velocity < -100
        let retreat = effectiveTranslation > threshold || velocity > 100

        let oldReal = realPage

        withAnimation(.easeInOut(duration: animDuration)) {
            dragOffset = 0

            if pageSnapping {
                if advance {
                    currentPage = min(currentPage + 1, pageCount - 1)
                } else if retreat {
                    currentPage = max(currentPage - 1, 0)
                }
            } else {
                // Best-effort: settle to the closest page using predicted end location.
                let predictedPage = CGFloat(currentPage) - effectivePredicted / pageExtent
                currentPage = min(max(Int(round(predictedPage)), 0), pageCount - 1)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {
            snapInfiniteLoop()
        }

        let newReal = realPage
        if newReal != oldReal {
            onChanged(newReal)
        }
    }

    private func jumpTo(realIndex: Int) {
        withAnimation(.easeInOut(duration: animDuration)) {
            currentPage = phantomOffset + realIndex
        }
        onChanged(realIndex)
    }

    private func snapInfiniteLoop() {
        guard infiniteScroll, pages.count > 1 else { return }
        // Phantom first page is at index 0, phantom last page is at displayPages.count - 1
        if currentPage <= 0 {
            currentPage = pages.count   // jump to real last page (displayPages[pages.count])
        } else if currentPage >= displayPages.count - 1 {
            currentPage = 1             // jump to real first page (displayPages[1])
        }
    }

    private func resolvedHeight(containerWidth: CGFloat) -> CGFloat {
        if let height { return height }
        if let aspectRatio, aspectRatio > 0 {
            return containerWidth / CGFloat(aspectRatio)
        }
        return containerWidth * 0.5
    }

    private func totalHeight(containerWidth: CGFloat) -> CGFloat {
        let contentHeight = resolvedHeight(containerWidth: containerWidth)
        guard showIndicator else { return contentHeight }
        return contentHeight + CGFloat(dotSizeHeight * 2.5) + 8
    }

    private var dotSizeHeight: Double {
        max(dotHeight, 0)
    }
}

// MARK: - DigiaDragGestureModifier

private struct DigiaDragGestureModifier: ViewModifier {
    let onChanged: (DragGesture.Value) -> Void
    let onEnded: (DragGesture.Value) -> Void

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture()
                .onChanged { onChanged($0) }
                .onEnded { onEnded($0) }
        )
    }
}

// MARK: - Indicator (Flutter smooth_page_indicator parity)

private enum DigiaIndicatorEffectType: String, CaseIterable {
    case worm
    case slide
    case swap
    case expanding
    case scale
    case jumping
    case scrolling
    case circleAroundDot
}

private struct DigiaCarouselIndicator: View {
    let effectType: DigiaIndicatorEffectType
    let pageProgress: Double
    let count: Int
    let dotSize: CGSize
    let spacing: Double
    let offset: Double
    let dotColor: Color
    let activeDotColor: Color
    let onDotTapped: (Int) -> Void

    private var step: CGFloat { CGFloat(dotSize.width + spacing) }
    private var totalWidth: CGFloat { CGFloat(max(count - 1, 0)) * step + CGFloat(dotSize.width) }
    private var usesCircleDots: Bool { abs(dotSize.width - dotSize.height) < 0.5 }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { idx in
                    inactiveDot
                        .frame(width: dotSize.width, height: dotSize.height)
                        .contentShape(Rectangle())
                        .onTapGesture { onDotTapped(idx) }
                }
            }

            activeOverlay()
                .allowsHitTesting(false)
        }
        .frame(width: totalWidth, height: dotSize.height * 2.5, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.22), value: pageProgress)
    }

    private var inactiveDot: some View {
        Group {
            if usesCircleDots {
                Circle().fill(dotColor)
            } else {
                Capsule().fill(dotColor)
            }
        }
    }

    @ViewBuilder
    private func activeOverlay() -> some View {
        let p = CGFloat(pageProgress)
        let i = max(0, min(Int(floor(p)), max(count - 1, 0)))
        let t = p - CGFloat(i) // 0..1

        switch effectType {
        case .slide:
            // SlideEffect: active dot translates and can overshoot by `offset`.
            let base = CGFloat(i) * step
            let travel = (t * step) + (sin(t * .pi) * CGFloat(offset))
            activeDotFill
                .frame(width: dotSize.width, height: dotSize.height)
                .offset(x: base + travel)

        case .worm:
            // WormEffect: active dot stretches between pages.
            let startX = CGFloat(i) * step
            let endX = CGFloat(min(i + 1, count - 1)) * step
            let leading = min(startX, startX + (endX - startX) * t)
            let trailing = max(startX + dotSize.width, startX + dotSize.width + (endX - startX) * t)
            Capsule()
                .fill(activeDotColor)
                .frame(width: max(trailing - leading, dotSize.width), height: dotSize.height)
                .offset(x: leading)

        case .expanding:
            // ExpandingDotsEffect: active dot widens.
            let base = p * step
            Capsule()
                .fill(activeDotColor)
                .frame(width: dotSize.width * (1.0 + 0.8 * (1.0 - abs(2 * Double(t) - 1.0))),
                       height: dotSize.height)
                .offset(x: base)

        case .scale:
            let base = p * step
            activeDotFill
                .frame(width: dotSize.width, height: dotSize.height)
                .scaleEffect(1.0 + 0.35 * (1.0 - abs(2 * Double(t) - 1.0)))
                .offset(x: base)

        case .jumping:
            let base = p * step
            activeDotFill
                .frame(width: dotSize.width, height: dotSize.height)
                .offset(x: base, y: -CGFloat(6.0 * sin(Double(t) * .pi)))

        case .swap:
            // SwapEffect: two dots swap; approximate by fading between current and next.
            let currentX = CGFloat(i) * step
            let nextX = CGFloat(min(i + 1, count - 1)) * step
            activeDotFill
                .frame(width: dotSize.width, height: dotSize.height)
                .opacity(1 - Double(t))
                .offset(x: currentX)
            activeDotFill
                .frame(width: dotSize.width, height: dotSize.height)
                .opacity(Double(t))
                .offset(x: nextX)

        case .scrolling:
            // ScrollingDotsEffect: windowed indicator; approximate by same base dots + moving active dot.
            let base = p * step
            activeDotFill
                .frame(width: dotSize.width, height: dotSize.height)
                .offset(x: base)

        case .circleAroundDot:
            let base = p * step
            ZStack {
                activeDotFill
                    .frame(width: dotSize.width, height: dotSize.height)
                Circle()
                    .stroke(activeDotColor, lineWidth: 2)
                    .frame(width: dotSize.height + dotSize.height * 1.5, height: dotSize.height + dotSize.height * 1.5)
            }
            .offset(x: base)
        }
    }

    private var activeDotFill: some View {
        Group {
            if usesCircleDots {
                Circle().fill(activeDotColor)
            } else {
                Capsule().fill(activeDotColor)
            }
        }
    }
}
