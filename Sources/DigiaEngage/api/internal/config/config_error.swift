import Foundation

enum DigiaConfigError: Error, Equatable {
    case unsupportedFlavor
    case invalidConfig(String)
    case cacheMiss(String)
    case network(String)
    case decodeFailure(String)
    case unsupportedFeature(String)
}
