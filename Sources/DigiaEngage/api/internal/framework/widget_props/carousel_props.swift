import Foundation

struct CarouselProps: Decodable, Equatable, Sendable {
    let width: ExprOr<Double>?
    let height: ExprOr<Double>?
    let direction: String?
    let aspectRatio: Double?
    let initialPage: ExprOr<Int>?
    let enlargeCenterPage: Bool?
    let viewportFraction: Double?
    let autoPlay: Bool?
    let animationDuration: Int?
    let autoPlayInterval: Int?
    let infiniteScroll: Bool?
    let reverseScroll: Bool?
    let enlargeFactor: Double?
    let showIndicator: Bool?
    let offset: Double?
    let dotHeight: Double?
    let dotWidth: Double?
    let padEnds: Bool?
    let spacing: Double?
    let pageSnapping: Bool?
    let dotColor: ExprOr<String>?
    let activeDotColor: ExprOr<String>?
    let indicatorEffectType: String?
    let keepAlive: Bool?
    let onChanged: ActionFlow?
    let dataSource: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case width
        case height
        case direction
        case aspectRatio
        case initialPage
        case enlargeCenterPage
        case viewportFraction
        case autoPlay
        case animationDuration
        case autoPlayInterval
        case infiniteScroll
        case reverseScroll
        case enlargeFactor
        case showIndicator
        case offset
        case dotHeight
        case dotWidth
        case padEnds
        case spacing
        case pageSnapping
        case dotColor
        case activeDotColor
        case indicatorEffectType
        case keepAlive
        case onChanged
        case dataSource
        case indicator
        case indicatorAvailable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let indicatorContainer = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .indicator)
        let indicatorAvailableContainer = try? indicatorContainer?.nestedContainer(keyedBy: CodingKeys.self, forKey: .indicatorAvailable)

        width = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .width)
        height = try container.decodeIfPresent(ExprOr<Double>.self, forKey: .height)
        direction = try container.decodeIfPresent(String.self, forKey: .direction)
        aspectRatio = try container.decodeIfPresent(Double.self, forKey: .aspectRatio)
        initialPage = try container.decodeIfPresent(ExprOr<Int>.self, forKey: .initialPage)
        enlargeCenterPage = try container.decodeIfPresent(Bool.self, forKey: .enlargeCenterPage)
        viewportFraction = try container.decodeIfPresent(Double.self, forKey: .viewportFraction)
        autoPlay = try container.decodeIfPresent(Bool.self, forKey: .autoPlay)
        animationDuration = try container.decodeIfPresent(Int.self, forKey: .animationDuration)
        autoPlayInterval = try container.decodeIfPresent(Int.self, forKey: .autoPlayInterval)
        infiniteScroll = try container.decodeIfPresent(Bool.self, forKey: .infiniteScroll)
        reverseScroll = try container.decodeIfPresent(Bool.self, forKey: .reverseScroll)
        enlargeFactor = try container.decodeIfPresent(Double.self, forKey: .enlargeFactor)
        showIndicator = try indicatorAvailableContainer?.decodeIfPresent(Bool.self, forKey: .showIndicator)
            ?? container.decodeIfPresent(Bool.self, forKey: .showIndicator)
        offset = try indicatorAvailableContainer?.decodeIfPresent(Double.self, forKey: .offset)
            ?? container.decodeIfPresent(Double.self, forKey: .offset)
        dotHeight = try indicatorAvailableContainer?.decodeIfPresent(Double.self, forKey: .dotHeight)
            ?? container.decodeIfPresent(Double.self, forKey: .dotHeight)
        dotWidth = try indicatorAvailableContainer?.decodeIfPresent(Double.self, forKey: .dotWidth)
            ?? container.decodeIfPresent(Double.self, forKey: .dotWidth)
        padEnds = try container.decodeIfPresent(Bool.self, forKey: .padEnds)
        spacing = try indicatorAvailableContainer?.decodeIfPresent(Double.self, forKey: .spacing)
            ?? container.decodeIfPresent(Double.self, forKey: .spacing)
        pageSnapping = try container.decodeIfPresent(Bool.self, forKey: .pageSnapping)
        dotColor = try indicatorAvailableContainer?.decodeIfPresent(ExprOr<String>.self, forKey: .dotColor)
            ?? container.decodeIfPresent(ExprOr<String>.self, forKey: .dotColor)
        activeDotColor = try indicatorAvailableContainer?.decodeIfPresent(ExprOr<String>.self, forKey: .activeDotColor)
            ?? container.decodeIfPresent(ExprOr<String>.self, forKey: .activeDotColor)
        indicatorEffectType = try indicatorAvailableContainer?.decodeIfPresent(String.self, forKey: .indicatorEffectType)
            ?? container.decodeIfPresent(String.self, forKey: .indicatorEffectType)
        keepAlive = try container.decodeIfPresent(Bool.self, forKey: .keepAlive)
        onChanged = try container.decodeIfPresent(ActionFlow.self, forKey: .onChanged)
        dataSource = try container.decodeIfPresent(JSONValue.self, forKey: .dataSource)
    }
}
