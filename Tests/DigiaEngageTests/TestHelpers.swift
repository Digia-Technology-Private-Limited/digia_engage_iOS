import Foundation
@testable import DigiaEngage

func makeTempConfigFile(_ json: String) throws -> String {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
    try Data(json.utf8).write(to: url)
    return url.path
}

func validConfigJSON(version: Int) -> String {
    """
    {
      "appSettings": { "initialRoute": "home" },
      "pages": { "home": { "uid": "home" } },
      "rest": {},
      "theme": { "colors": { "light": {} } },
      "version": \(version)
    }
    """
}

@MainActor
func context(appConfig: AppConfigStore = AppConfigStore(), localStateStore: StateContext? = nil) -> ActionProcessorContext {
    ActionProcessorContext(
        appConfig: appConfig,
        localStateStore: localStateStore
    )
}

final class MockConfigNetworkClient: ConfigNetworkClient {
    let metadata: [String: Any]
    let downloadedData: Data?
    private(set) var downloadCallCount = 0

    init(metadata: [String: Any], downloadedData: Data?) {
        self.metadata = metadata
        self.downloadedData = downloadedData
    }

    func fetchJSON(path: String, headers: [String : String], body: [String : Any]) async throws -> [String : Any] {
        metadata
    }

    func download(url: String) async throws -> Data {
        downloadCallCount += 1
        return downloadedData ?? Data()
    }
}
