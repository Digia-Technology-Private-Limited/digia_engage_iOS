import Foundation

struct AssetConfigSource: DigiaConfigSource {
    let appConfigPath: String

    func getConfig() throws -> DigiaAppConfig {
        let fileURL = URL(fileURLWithPath: appConfigPath)
        let data = try Data(contentsOf: fileURL)
        return try DigiaAppConfig.decode(from: data)
    }
}
