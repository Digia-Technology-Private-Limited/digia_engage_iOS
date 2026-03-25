import SwiftUI

@MainActor
protocol VirtualWidgetRegistry {
    func createWidget(_ data: VWData, parent: VirtualWidget?) throws -> VirtualWidget
}

enum VirtualWidgetRegistryError: Error, Equatable {
    case unsupportedWidgetType(String)
}
