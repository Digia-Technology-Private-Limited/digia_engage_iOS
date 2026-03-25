public struct DiagnosticReport: Sendable, Equatable {
    public let isHealthy: Bool
    public let issue: String?
    public let resolution: String?
    public let metadata: [String: String]

    public init(
        isHealthy: Bool,
        issue: String? = nil,
        resolution: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.isHealthy = isHealthy
        self.issue = issue
        self.resolution = resolution
        self.metadata = metadata
    }
}
