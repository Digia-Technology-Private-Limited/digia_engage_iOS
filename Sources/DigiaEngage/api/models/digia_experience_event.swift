public enum DigiaExperienceEvent: Sendable, Equatable {
    case impressed
    case clicked(elementID: String? = nil)
    case dismissed
}
