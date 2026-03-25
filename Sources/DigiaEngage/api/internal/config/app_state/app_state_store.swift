import Foundation

enum AppStateStoreError: Error, Equatable, LocalizedError {
    case duplicateKey(String)
    case unknownType(String)
    case missingKey(String)
    case typeMismatch(key: String, expected: AppStateValueType, actual: JSONValue)

    var errorDescription: String? {
        switch self {
        case let .duplicateKey(key):
            return "Duplicate appState key: \(key)"
        case let .unknownType(type):
            return "Unknown appState type: \(type)"
        case let .missingKey(key):
            return "AppState key not found: \(key)"
        case let .typeMismatch(key, expected, actual):
            return "Type mismatch for appState key '\(key)'. Expected \(expected.rawValue), got \(actual)"
        }
    }
}

enum AppStateValueType: String, Sendable, Equatable {
    case number
    case string
    case bool
    case json
    case list

    init(rawOrAlias: String) throws {
        switch rawOrAlias {
        case "number", "numeric":
            self = .number
        case "string":
            self = .string
        case "bool", "boolean":
            self = .bool
        case "json":
            self = .json
        case "list", "array":
            self = .list
        default:
            throw AppStateStoreError.unknownType(rawOrAlias)
        }
    }
}

private struct AppStateEntry: Sendable {
    let descriptor: AppStateDefinition
    let type: AppStateValueType
    var value: JSONValue
}

@MainActor
final class AppStateStore {
    private let namespace: String
    private let storage: UserDefaults
    private var entries: [String: AppStateEntry] = [:]

    init(definitions: [AppStateDefinition], namespace: String, storage: UserDefaults = .standard) throws {
        self.namespace = namespace
        self.storage = storage

        for definition in definitions {
            if entries[definition.name] != nil {
                throw AppStateStoreError.duplicateKey(definition.name)
            }

            let type = try AppStateValueType(rawOrAlias: definition.type)
            let defaultValue = normalize(value: definition.value, for: type)
            let loadedValue = loadPersistedValue(
                key: definition.name,
                type: type,
                shouldPersist: definition.shouldPersist
            ) ?? defaultValue
            let entry = AppStateEntry(descriptor: definition, type: type, value: loadedValue)
            entries[definition.name] = entry
        }
    }

    func snapshot() -> [String: JSONValue] {
        entries.mapValues(\.value)
    }

    func contains(_ key: String) -> Bool {
        entries[key] != nil
    }

    func streamName(for key: String) -> String? {
        entries[key]?.descriptor.streamName
    }

    func update(key: String, value: JSONValue) throws {
        guard var entry = entries[key] else {
            throw AppStateStoreError.missingKey(key)
        }

        let normalized = normalizeIfMatchingType(value: value, for: entry.type)
        guard let normalized else {
            throw AppStateStoreError.typeMismatch(key: key, expected: entry.type, actual: value)
        }

        entry.value = normalized
        entries[key] = entry

        if entry.descriptor.shouldPersist {
            persist(value: normalized, key: key, type: entry.type)
        }
    }

    private func persist(value: JSONValue, key: String, type: AppStateValueType) {
        let storageKey = makeStorageKey(key: key)
        let encoded = encodeForStorage(value: value, as: type)
        storage.set(encoded, forKey: storageKey)
    }

    private func loadPersistedValue(key: String, type: AppStateValueType, shouldPersist: Bool) -> JSONValue? {
        guard shouldPersist else { return nil }
        let storageKey = makeStorageKey(key: key)
        guard let raw = storage.string(forKey: storageKey) else { return nil }
        return decodeFromStorage(raw: raw, as: type)
    }

    private func makeStorageKey(key: String) -> String {
        "\(namespace)_app_state_\(key)"
    }

    private func normalize(value: JSONValue?, for type: AppStateValueType) -> JSONValue {
        guard let value else {
            switch type {
            case .number: return .int(0)
            case .string: return .string("")
            case .bool: return .bool(false)
            case .json: return .object([:])
            case .list: return .array([])
            }
        }
        return normalizeLossy(value: value, for: type)
    }

    private func normalizeIfMatchingType(value: JSONValue, for type: AppStateValueType) -> JSONValue? {
        switch (type, value) {
        case (.string, .string):
            return value
        case (.number, .int), (.number, .double):
            return value
        case (.bool, .bool):
            return value
        case (.json, .object):
            return value
        case (.list, .array):
            return value
        default:
            return nil
        }
    }

    private func normalizeLossy(value: JSONValue, for type: AppStateValueType) -> JSONValue {
        switch type {
        case .string:
            switch value {
            case let .string(v): return .string(v)
            case let .int(v): return .string(String(v))
            case let .double(v): return .string(String(v))
            case let .bool(v): return .string(String(v))
            case let .array(v): return .string(String(describing: v.map(\.anyValue)))
            case let .object(v): return .string(String(describing: v.mapValues(\.anyValue)))
            case .null: return .string("")
            }
        case .number:
            switch value {
            case let .int(v): return .int(v)
            case let .double(v): return .double(v)
            case let .string(v):
                if let intValue = Int(v) { return .int(intValue) }
                if let doubleValue = Double(v) { return .double(doubleValue) }
                return .int(0)
            default:
                return .int(0)
            }
        case .bool:
            switch value {
            case let .bool(v): return .bool(v)
            case let .int(v): return .bool(v != 0)
            case let .double(v): return .bool(v != 0)
            case let .string(v): return .bool(Bool(v) ?? false)
            default: return .bool(false)
            }
        case .json:
            if case .object = value {
                return value
            }
            if case let .string(raw) = value,
               let data = raw.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data)
            {
                return .object(decoded)
            }
            return .object([:])
        case .list:
            if case .array = value {
                return value
            }
            if case let .string(raw) = value,
               let data = raw.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([JSONValue].self, from: data)
            {
                return .array(decoded)
            }
            return .array([])
        }
    }

    private func encodeForStorage(value: JSONValue, as type: AppStateValueType) -> String {
        switch type {
        case .string:
            if case let .string(v) = value { return v }
            return ""
        case .number:
            switch value {
            case let .int(v): return String(v)
            case let .double(v): return String(v)
            default: return "0"
            }
        case .bool:
            if case let .bool(v) = value { return String(v) }
            return "false"
        case .json:
            if case let .object(v) = value,
               let data = try? JSONEncoder().encode(v),
               let string = String(data: data, encoding: .utf8)
            {
                return string
            }
            return "{}"
        case .list:
            if case let .array(v) = value,
               let data = try? JSONEncoder().encode(v),
               let string = String(data: data, encoding: .utf8)
            {
                return string
            }
            return "[]"
        }
    }

    private func decodeFromStorage(raw: String, as type: AppStateValueType) -> JSONValue {
        switch type {
        case .string:
            return .string(raw)
        case .number:
            if let intValue = Int(raw) { return .int(intValue) }
            if let doubleValue = Double(raw) { return .double(doubleValue) }
            return .int(0)
        case .bool:
            return .bool(Bool(raw) ?? false)
        case .json:
            if let data = raw.data(using: .utf8),
               let value = try? JSONDecoder().decode([String: JSONValue].self, from: data)
            {
                return .object(value)
            }
            return .object([:])
        case .list:
            if let data = raw.data(using: .utf8),
               let value = try? JSONDecoder().decode([JSONValue].self, from: data)
            {
                return .array(value)
            }
            return .array([])
        }
    }
}
