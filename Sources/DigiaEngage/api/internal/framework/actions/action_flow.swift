import Foundation

struct ActionFlow: Codable, Equatable, Sendable {
    let steps: [ActionStep]
    let inkwell: Bool
    let analyticsData: [AnalyticsDatum]

    init(steps: [ActionStep] = [], inkwell: Bool = true, analyticsData: [AnalyticsDatum] = []) {
        self.steps = steps
        self.inkwell = inkwell
        self.analyticsData = analyticsData
    }

    var isEmpty: Bool {
        steps.isEmpty && analyticsData.isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case steps
        case inkwell = "inkWell"
        case analyticsData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        steps = try container.decodeIfPresent([ActionStep].self, forKey: .steps) ?? []
        inkwell = try container.decodeIfPresent(Bool.self, forKey: .inkwell) ?? true
        analyticsData = try container.decodeIfPresent([AnalyticsDatum].self, forKey: .analyticsData) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(steps, forKey: .steps)
        try container.encode(inkwell, forKey: .inkwell)
        try container.encode(analyticsData, forKey: .analyticsData)
    }
}

struct ActionStep: Codable, Equatable, Sendable {
    let type: String
    let data: [String: JSONValue]?
    let disableActionIf: ExprOr<Bool>?

    init(type: String, data: [String: JSONValue]? = nil, disableActionIf: ExprOr<Bool>? = nil) {
        self.type = type
        self.data = data
        self.disableActionIf = disableActionIf
    }
}

struct AnalyticsDatum: Codable, Equatable, Sendable {
    let key: String?
    let value: String?
}

extension JSONValue {
    func asActionFlow() -> ActionFlow? {
        guard case let .object(object) = self,
              case let .array(steps)? = object["steps"] else { return nil }
        let decodedSteps = steps.compactMap { item -> ActionStep? in
            guard case let .object(obj) = item,
                  let type = obj.string("type") else { return nil }
            return ActionStep(type: type, data: obj.object("data"), disableActionIf: nil)
        }
        return ActionFlow(steps: decodedSteps)
    }
}
