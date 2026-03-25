import Foundation

struct DigiaAppConfig: Decodable, Equatable {
    let appSettings: AppSettings
    let pages: [String: PageDefinition]
    let components: [String: ComponentDefinition]?
    let appState: [AppStateDefinition]?
    let rest: RestConfiguration
    let theme: ThemeConfiguration
    let version: Int?

    var initialRoute: String { appSettings.initialRoute }

    func page(_ id: String) -> PageDefinition? {
        pages[id]
    }

    func component(_ id: String) -> ComponentDefinition? {
        components?[id]
    }

    static func decode(from data: Data) throws -> DigiaAppConfig {
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let result = try decode(jsonObject: object)
            return result
        } catch let error as DigiaConfigError {
            throw error
        } catch {
            throw DigiaConfigError.decodeFailure("Failed to parse app config JSON payload")
        }
    }

    static func decode(jsonObject: Any) throws -> DigiaAppConfig {
        guard let object = jsonObject as? [String: Any] else {
            throw DigiaConfigError.decodeFailure("App config must be a JSON object")
        }

        let payload: Any
        if let data = object["data"] as? [String: Any], let response = data["response"] {
            payload = response
        } else if let response = object["response"] {
            payload = response
        } else {
            payload = object
        }

        let normalized: Data
        do {
            normalized = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            throw DigiaConfigError.decodeFailure("Failed to normalize app config payload")
        }
        do {
            return try JSONDecoder().decode(DigiaAppConfig.self, from: normalized)
        } catch {
            throw DigiaConfigError.decodeFailure("Failed to decode AppConfig: \(error.localizedDescription)")
        }
    }
}

struct AppStateDefinition: Decodable, Equatable, Sendable {
    let name: String
    let type: String
    let value: JSONValue?
    let shouldPersist: Bool
    let streamName: String

    init(name: String, type: String, value: JSONValue?, shouldPersist: Bool, streamName: String) {
        self.name = name
        self.type = type
        self.value = value
        self.shouldPersist = shouldPersist
        self.streamName = streamName
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case value
        case shouldPersist
        case streamName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value)
        shouldPersist = try container.decodeIfPresent(Bool.self, forKey: .shouldPersist) ?? false
        streamName = try container.decodeIfPresent(String.self, forKey: .streamName) ?? "\(name)changeStream"
    }
}

struct AppSettings: Decodable, Equatable {
    let initialRoute: String
}

struct PageDefinition: Decodable, Equatable {
    let uid: String?
    let slug: String?
    let inputArgs: [String: Variable]?
    let initStateDefs: [String: Variable]?
    let layout: LayoutDefinition?
    let actions: PageActions?

    enum CodingKeys: String, CodingKey {
        case uid
        case slug
        case inputArgs
        case pageArgDefs
        case argDefs
        case variables
        case initStateDefs
        case layout
        case actions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uid = try container.decodeIfPresent(String.self, forKey: .uid)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        inputArgs = try container.decodeIfPresent([String: Variable].self, forKey: .inputArgs)
            ?? container.decodeIfPresent([String: Variable].self, forKey: .pageArgDefs)
            ?? container.decodeIfPresent([String: Variable].self, forKey: .argDefs)
        initStateDefs = try container.decodeIfPresent([String: Variable].self, forKey: .variables)
            ?? container.decodeIfPresent([String: Variable].self, forKey: .initStateDefs)
        layout = try container.decodeIfPresent(LayoutDefinition.self, forKey: .layout)
        actions = try container.decodeIfPresent(PageActions.self, forKey: .actions)
    }

    var renderRoot: VWData? {
        layout?.renderRoot
    }
}

struct ComponentDefinition: Decodable, Equatable {
    let uid: String?
    let argDefs: [String: Variable]?
    let initStateDefs: [String: Variable]?
    let layout: LayoutDefinition?

    enum CodingKeys: String, CodingKey {
        case uid
        case argDefs
        case initStateDefs
        case layout
    }

    var renderRoot: VWData? {
        layout?.renderRoot
    }
}

struct PageActions: Decodable, Equatable {
    let onPageLoadAction: ActionFlow?
    let onBackPress: ActionFlow?
}

struct LayoutDefinition: Decodable, Equatable {
    let root: VWData?
    let body: LayoutBody?

    var renderRoot: VWData? { root ?? body?.root }
}

struct LayoutBody: Decodable, Equatable {
    let root: VWData?
}

struct RestConfiguration: Decodable, Equatable {
    let baseUrl: String?
    let defaultHeaders: [String: String]?
    let resources: [String: APIModel]?

    func resource(_ id: String) -> APIModel? {
        resources?[id]
    }
}

struct ThemeConfiguration: Decodable, Equatable {
    let colors: ThemeColorConfiguration?
    let fonts: [String: FontDescriptorProps]?
}

struct ThemeColorConfiguration: Decodable, Equatable {
    let light: [String: String]
    let dark: [String: String]?
}
