import SwiftUI
import UIKit

enum To {
    static func mainAxisAlignment(_ value: String?) -> DigiaMainAxisAlignment {
        switch value {
        case "end":
            return .end
        case "center":
            return .center
        case "spaceBetween":
            return .spaceBetween
        case "spaceAround":
            return .spaceAround
        case "spaceEvenly":
            return .spaceEvenly
        default:
            return .start
        }
    }

    static func fontWeight(_ value: String?) -> Font.Weight {
        switch value {
        case "thin":
            return .thin
        case "extralight", "extraLight", "extra-light":
            return .ultraLight
        case "light":
            return .light
        case "medium":
            return .medium
        case "semibold", "semiBold", "semi-bold":
            return .semibold
        case "bold":
            return .bold
        case "extrabold", "extraBold", "extra-bold":
            return .heavy
        case "black":
            return .black
        default:
            return .regular
        }
    }

    static func alignment(_ value: String?) -> Alignment? {
        switch value {
        case "topLeft", "topStart":
            return .topLeading
        case "topCenter":
            return .top
        case "topRight", "topEnd":
            return .topTrailing
        case "centerLeft", "centerStart", "start":
            return .leading
        case "center":
            return .center
        case "centerRight", "centerEnd", "end":
            return .trailing
        case "bottomLeft", "bottomStart":
            return .bottomLeading
        case "bottomCenter":
            return .bottom
        case "bottomRight", "bottomEnd":
            return .bottomTrailing
        default:
            return nil
        }
    }

    static func textAlignment(_ value: String?) -> TextAlignment {
        switch value {
        case "right", "end", "centerRight", "centerEnd":
            return .trailing
        case "center", "topCenter", "bottomCenter":
            return .center
        case "justify":
            return .leading
        default:
            return .leading
        }
    }

    static func crossAxisAlignment(_ value: String?) -> HorizontalAlignment {
        switch value {
        case "start":
            return .leading
        case "end":
            return .trailing
        case "center":
            return .center
        case "stretch", "baseline":
            return .leading
        default:
            return .leading
        }
    }

    static func verticalAlignment(_ value: String?) -> VerticalAlignment {
        switch value {
        case "start":
            return .top
        case "end":
            return .bottom
        default:
            return .center
        }
    }

    static func imageContentMode(_ value: String?) -> ContentMode {
        switch value {
        case "fill", "cover":
            return .fill
        default:
            return .fit
        }
    }

    static func strokeCap(_ value: String?) -> CGLineCap {
        switch value {
        case "round":
            return .round
        case "square":
            return .square
        default:
            return .butt
        }
    }

    static func edgeInsets(_ spacing: Spacing?) -> EdgeInsets? {
        spacing?.edgeInsets
    }

    static func unitPoint(_ value: String?) -> UnitPoint? {
        switch value {
        case "topLeft", "topStart":
            return .topLeading
        case "topCenter":
            return .top
        case "topRight", "topEnd":
            return .topTrailing
        case "centerLeft", "centerStart", "left", "start":
            return .leading
        case "center":
            return .center
        case "centerRight", "centerEnd", "right", "end":
            return .trailing
        case "bottomLeft", "bottomStart":
            return .bottomLeading
        case "bottomCenter":
            return .bottom
        case "bottomRight", "bottomEnd":
            return .bottomTrailing
        default:
            return nil
        }
    }

    static func uiTextAlignment(_ value: String?) -> NSTextAlignment {
        switch value {
        case "right", "end", "centerRight", "centerEnd":
            return .right
        case "center", "topCenter", "bottomCenter":
            return .center
        case "justify":
            return .justified
        default:
            return .left
        }
    }

    static func uiLineBreakMode(_ value: String?) -> NSLineBreakMode {
        switch value {
        case "ellipsis":
            return .byTruncatingTail
        case "clip", "visible":
            return .byClipping
        default:
            return .byWordWrapping
        }
    }

    static func cornerRadius(_ rawValue: Any?) -> CornerRadiusProps? {
        switch rawValue {
        case let value as Double:
            return CornerRadiusProps(uniform: value)
        case let value as Int:
            return CornerRadiusProps(uniform: Double(value))
        case let value as NSNumber:
            return CornerRadiusProps(uniform: value.doubleValue)
        case let value as String:
            let parts = value
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            return cornerRadiusFromList(parts)
        case let values as [Any?]:
            let parts = values.compactMap { toDouble($0) }
            return cornerRadiusFromList(parts)
        case let object as [String: Any?]:
            return CornerRadiusProps(
                topLeft: toDouble(object["topLeft"] ?? nil) ?? 0,
                topRight: toDouble(object["topRight"] ?? nil) ?? 0,
                bottomRight: toDouble(object["bottomRight"] ?? nil) ?? 0,
                bottomLeft: toDouble(object["bottomLeft"] ?? nil) ?? 0
            )
        default:
            return nil
        }
    }

    private static func cornerRadiusFromList(_ parts: [Double]) -> CornerRadiusProps? {
        switch parts.count {
        case 1:
            return CornerRadiusProps(uniform: parts[0])
        case 4:
            return CornerRadiusProps(
                topLeft: parts[0],
                topRight: parts[1],
                bottomRight: parts[2],
                bottomLeft: parts[3]
            )
        default:
            return nil
        }
    }

    static func toDouble(_ rawValue: Any?) -> Double? {
        switch rawValue {
        case let value as Double: return value
        case let value as Int: return Double(value)
        case let value as NSNumber: return value.doubleValue
        case let value as String: return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }
}
