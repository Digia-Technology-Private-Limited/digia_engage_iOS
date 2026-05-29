import SwiftUI

@MainActor
final class DigiaStoryController: ObservableObject {
    enum StoryAction: String {
        case play
        case pause
        case next
        case previous
        case mute
        case unMute
        case playCustomWidget
    }

    @Published fileprivate(set) var storyStatus: StoryAction = .play
    @Published fileprivate(set) var jumpIndex: Int?

    func play() { storyStatus = .play }
    func pause() { storyStatus = .pause }
    func next() { storyStatus = .next }
    func previous() { storyStatus = .previous }
    func mute() { storyStatus = .mute }
    func unMute() { storyStatus = .unMute }
    func playCustomWidget() { storyStatus = .playCustomWidget }
    func jumpTo(_ index: Int) { jumpIndex = index }

    func getField(_ name: String) -> Any? {
        switch name {
        case "isPaused": return storyStatus == .pause
        case "isMuted":  return storyStatus == .mute
        default:         return nil
        }
    }
}
