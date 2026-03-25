import Foundation

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

enum VWData: Decodable, Equatable, Sendable {
    case widget(VWNodeData)
    case component(VWComponentData)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decodeIfPresent(String.self, forKey: .category)
        switch NodeType.fromString(raw) {
        case .component:
            self = .component(try VWComponentData(from: decoder))
        default:
            self = .widget(try VWNodeData(from: decoder))
        }
    }

    var refName: String? {
        switch self {
        case let .widget(data):
            return data.refName
        case let .component(data):
            return data.refName
        }
    }

    enum CodingKeys: String, CodingKey {
        case category
    }
}


struct VWNodeData: Decodable, Equatable, Sendable {
    let category: String
    let type: String
    let props: WidgetNodeProps
    let commonProps: CommonProps?
    let parentProps: ParentProps?
    /// Children stored as raw JSONValue to avoid recursive JSONDecoder stack frames.
    /// The registry decodes each child one level at a time when building the widget tree.
    let childGroups: [String: [JSONValue]]
    let repeatData: JSONValue?
    let refName: String?

    init(
        category: String,
        type: String,
        props: WidgetNodeProps,
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        childGroups: [String: [JSONValue]],
        repeatData: JSONValue?,
        refName: String?
    ) {
        self.category = category
        self.type = type
        self.props = props
        self.commonProps = commonProps
        self.parentProps = parentProps
        self.childGroups = childGroups
        self.repeatData = repeatData
        self.refName = refName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "widget"
        commonProps = try container.decodeIfPresent(CommonProps.self, forKey: .containerProps)
        parentProps = try container.decodeIfPresent(ParentProps.self, forKey: .parentProps)

        if let repeatValue = try container.decodeIfPresent(JSONValue.self, forKey: .repeatData) {
            repeatData = repeatValue
        } else if let dataRefValue = try container.decodeIfPresent(JSONValue.self, forKey: .dataRef) {
            repeatData = dataRefValue
        } else {
            repeatData = nil
        }

        refName = try container.decodeIfPresent(String.self, forKey: .varName) ?? container.decodeIfPresent(String.self, forKey: .refName)
        props = try WidgetNodeProps.decode(type: type, from: container, forKey: .props)

        childGroups = try ChildGroups(from: decoder).value
    }

    enum CodingKeys: String, CodingKey {
        case category
        case type
        case props
        case containerProps
        case parentProps
        case repeatData
        case dataRef
        case varName
        case refName
    }
}


struct VWComponentData: Decodable, Equatable, Sendable {
    let category: String
    let id: String
    let args: [String: JSONValue]?
    let commonProps: CommonProps?
    let parentProps: ParentProps?
    let refName: String?

    private enum CodingKeys: String, CodingKey {
        case category
        case componentId
        case componentArgs
        case containerProps
        case parentProps
        case varName
        case refName
    }

    init(
        category: String,
        id: String,
        args: [String: JSONValue]?,
        commonProps: CommonProps?,
        parentProps: ParentProps?,
        refName: String?
    ) {
        self.category = category
        self.id = id
        self.args = args
        self.commonProps = commonProps
        self.parentProps = parentProps
        self.refName = refName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "component"
        id = try container.decode(String.self, forKey: .componentId)
        args = try container.decodeIfPresent([String: JSONValue].self, forKey: .componentArgs)
        commonProps = try container.decodeIfPresent(CommonProps.self, forKey: .containerProps)
        parentProps = try container.decodeIfPresent(ParentProps.self, forKey: .parentProps)
        refName = try container.decodeIfPresent(String.self, forKey: .varName) ?? container.decodeIfPresent(String.self, forKey: .refName)
    }
}

private struct ChildGroups: Decodable, Equatable, Sendable {
    let value: [String: [JSONValue]]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.childGroups) {
            value = try Self.decodeGroupValue(from: container, key: .childGroups)
            return
        }
        if container.contains(.composites) {
            value = try Self.decodeGroupValue(from: container, key: .composites)
            return
        }
        if container.contains(.children) {
            value = try Self.decodeGroupValue(from: container, key: .children)
            return
        }

        value = [:]
    }

    private enum CodingKeys: String, CodingKey {
        case children
        case composites
        case childGroups
    }

    private static func decodeGroupValue(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> [String: [JSONValue]] {
        let groupDecoder = try container.superDecoder(forKey: key)

        // Decode children as JSONValue (not VWData) to avoid recursive JSONDecoder stack
        // frames for deeply nested widget trees. The registry decodes VWData lazily.
        if let keyed = try? groupDecoder.container(keyedBy: DynamicCodingKey.self) {
            var result: [String: [JSONValue]] = [:]
            result.reserveCapacity(keyed.allKeys.count)
            for k in keyed.allKeys {
                var arrayContainer = try keyed.nestedUnkeyedContainer(forKey: k)
                var items: [JSONValue] = []
                items.reserveCapacity(arrayContainer.count ?? 0)
                while !arrayContainer.isAtEnd {
                    items.append(try arrayContainer.decode(JSONValue.self))
                }
                result[k.stringValue] = items
            }
            return result
        }

        if var unkeyed = try? groupDecoder.unkeyedContainer() {
            var items: [JSONValue] = []
            items.reserveCapacity(unkeyed.count ?? 0)
            while !unkeyed.isAtEnd {
                items.append(try unkeyed.decode(JSONValue.self))
            }
            return ["children": items]
        }

        return [:]
    }
}
