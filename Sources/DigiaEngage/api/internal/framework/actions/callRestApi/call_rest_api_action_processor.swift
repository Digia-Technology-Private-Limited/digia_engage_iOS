import Foundation

struct CallRestApiAction: Sendable {
    let actionType: ActionType = .callRestApi
    let disableActionIf: ExprOr<Bool>?
    let data: [String: JSONValue]
}

@MainActor
struct CallRestApiProcessor {
    let processorType: ActionType = .callRestApi

    func execute(action: CallRestApiAction, context: ActionProcessorContext) async throws {
        guard let dataSource = action.data.object("dataSource"),
              let dataSourceID = dataSource.string("id"),
              let apiModel = context.appConfig.appConfig?.rest.resource(dataSourceID) else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }

        let resolvedArgs = resolveArguments(apiModel: apiModel, dataSource: dataSource, context: context)
        let request = try makeRequest(apiModel: apiModel, args: resolvedArgs, baseURL: context.appConfig.appConfig?.rest.baseUrl)
        do {
            let (data, response): (Data, URLResponse?)
            if request.url?.isFileURL == true, let url = request.url {
                data = try Data(contentsOf: url)
                response = nil
            } else {
                let network = try await URLSession.shared.data(for: request)
                data = network.0
                response = network.1
            }
            let http = response as? HTTPURLResponse
            let responseObject = buildResponseObject(data: data, response: http, request: request, error: nil)
            let successContext = BasicExprContext(variables: ["response": responseObject.mapValues(\.anyValue)])
            if let scopeContext = context.scopeContext {
                successContext.addContextAtTail(scopeContext)
            }
            let isSuccess = evaluateSuccessCondition(action.data["successCondition"], scopeContext: successContext)
            let nextFlow = isSuccess ? action.data["onSuccess"]?.asActionFlow() : action.data["onError"]?.asActionFlow()
            await context.actionExecutor.executeNow(
                nextFlow,
                appConfig: context.appConfig,
                scopeContext: successContext,
                triggerType: isSuccess ? "onSuccess" : "onError",
                localStateStore: context.localStateStore
            )
        } catch {
            let responseObject = buildResponseObject(data: nil, response: nil, request: request, error: error)
            let errorContext = BasicExprContext(variables: ["response": responseObject.mapValues(\.anyValue)])
            if let scopeContext = context.scopeContext {
                errorContext.addContextAtTail(scopeContext)
            }
            await context.actionExecutor.executeNow(
                action.data["onError"]?.asActionFlow(),
                appConfig: context.appConfig,
                scopeContext: errorContext,
                triggerType: "onError",
                localStateStore: context.localStateStore
            )
            throw error
        }
    }

    private func evaluateSuccessCondition(_ value: JSONValue?, scopeContext: any ExprContext) -> Bool {
        guard case let .string(expression)? = value else { return true }
        guard ExpressionUtil.hasExpression(expression) else { return true }
        return ExpressionUtil.evaluateExpression(expression, context: scopeContext) ?? true
    }

    private func resolveArguments(apiModel: APIModel, dataSource: [String: JSONValue], context: ActionProcessorContext) -> [String: JSONValue] {
        let configured = apiModel.variables?.mapValues { $0.resolvedValue(in: context.scopeContext) } ?? [:]
        let inline = dataSource.object("args")?.mapValues { ExpressionUtil.evaluateNestedExpressions($0, in: context.scopeContext) } ?? [:]
        return configured.merging(inline) { _, rhs in rhs }
    }

    private func makeRequest(apiModel: APIModel, args: [String: JSONValue], baseURL: String?) throws -> URLRequest {
        let hydratedURL = hydrateTemplate(apiModel.url, args: args)
        let urlString = hydratedURL.hasPrefix("http") ? hydratedURL : (baseURL ?? "") + hydratedURL
        guard let url = URL(string: urlString) else {
            throw ActionExecutionError.unsupportedContext(processorType)
        }
        var request = URLRequest(url: url)
        request.httpMethod = apiModel.method.uppercased()
        var headers = apiModel.headers?.reduce(into: [String: String]()) { partialResult, entry in
            partialResult[entry.key] = stringValue(from: hydrateJSONValue(entry.value, args: args))
        } ?? [:]
        headers["Content-Type", default: "application/json"] = "application/json"
        request.allHTTPHeaderFields = headers
        if apiModel.method.lowercased() != "get", let body = apiModel.body {
            let hydratedBody = hydrateJSONValue(body, args: args)
            request.httpBody = try JSONSerialization.data(withJSONObject: hydratedBody.anyValue ?? [:])
        }
        return request
    }

    private func hydrateJSONValue(_ value: JSONValue, args: [String: JSONValue]) -> JSONValue {
        switch value {
        case let .string(string):
            if string.contains("{{") {
                return .string(hydrateTemplate(string, args: args))
            }
            return value
        case let .array(values):
            return .array(values.map { hydrateJSONValue($0, args: args) })
        case let .object(values):
            return .object(values.mapValues { hydrateJSONValue($0, args: args) })
        default:
            return value
        }
    }

    private func hydrateTemplate(_ template: String, args: [String: JSONValue]) -> String {
        let regex = try? NSRegularExpression(pattern: #"\{\{([\w\.\-]+)\}\}"#)
        let range = NSRange(location: 0, length: template.utf16.count)
        let matches = regex?.matches(in: template, range: range) ?? []
        var result = template
        for match in matches.reversed() {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else { continue }
            let key = String(result[keyRange])
            let value = stringValue(from: args[key] ?? .null)
            result.replaceSubrange(fullRange, with: value)
        }
        return result
    }

    private func stringValue(from value: JSONValue) -> String {
        switch value {
        case let .string(value): return value
        case let .int(value): return String(value)
        case let .double(value): return String(value)
        case let .bool(value): return String(value)
        case let .array(value): return String(describing: value.map(\.anyValue))
        case let .object(value): return String(describing: value.mapValues(\.anyValue))
        case .null: return ""
        }
    }

    private func buildResponseObject(data: Data?, response: HTTPURLResponse?, request: URLRequest, error: Error?) -> [String: JSONValue] {
        let bodyObject: JSONValue
        if let data,
           let json = try? JSONSerialization.jsonObject(with: data) {
            bodyObject = ExpressionUtil.jsonValue(from: json)
        } else if let data, let string = String(data: data, encoding: .utf8) {
            bodyObject = .string(string)
        } else {
            bodyObject = .null
        }
        return [
            "body": bodyObject,
            "statusCode": response.map { .int($0.statusCode) } ?? .null,
            "headers": ExpressionUtil.jsonValue(from: response?.allHeaderFields as? [String: Any]),
            "requestObj": .object([
                "url": .string(request.url?.absoluteString ?? ""),
                "method": .string(request.httpMethod ?? "GET"),
            ]),
            "error": error.map { .string(String(describing: $0)) } ?? .null,
        ]
    }
}
