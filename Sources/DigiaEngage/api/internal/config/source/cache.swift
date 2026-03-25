import Foundation

struct CachedConfigSource: DigiaConfigSource {
    let cacheFilePath: String

    func getConfig() throws -> DigiaAppConfig {
        let fileURL = URL(fileURLWithPath: cacheFilePath)
        do {
            let data = try Data(contentsOf: fileURL)
            return try DigiaAppConfig.decode(from: data)
        } catch let error as DigiaConfigError {
            throw error
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            throw DigiaConfigError.cacheMiss(cacheFilePath)
        } catch {
            throw DigiaConfigError.decodeFailure("Failed to decode cached config at \(cacheFilePath)")
        }
    }
}
