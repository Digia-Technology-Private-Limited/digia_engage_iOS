import Combine
import SwiftUI
import UIKit

@MainActor
final class BottomSheetTransitionModel: ObservableObject {
    @Published var barrierOpacity: CGFloat = 0
    @Published var sheetOffset: CGFloat = 0
    private(set) var containerHeight: CGFloat = UIScreen.main.bounds.height

    private var didRunEnterAnimation = false

    func updateContainerHeight(_ height: CGFloat) {
        let h = height > 1 ? height : UIScreen.main.bounds.height
        containerHeight = h
    }

    func runEnterAnimationIfNeeded(containerHeight height: CGFloat) {
        guard !didRunEnterAnimation else { return }
        didRunEnterAnimation = true
        updateContainerHeight(height)
        sheetOffset = containerHeight
        barrierOpacity = 0
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.12)) {
                barrierOpacity = 1
            }
            try? await Task.sleep(nanoseconds: 24_000_000)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.9)) {
                sheetOffset = 0
            }
        }
    }

    func animateDismiss(completion: @escaping () -> Void) {
        let h = containerHeight
        withAnimation(.spring(response: 0.3, dampingFraction: 0.92)) {
            sheetOffset = h
        }
        withAnimation(.easeIn(duration: 0.22)) {
            barrierOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 320_000_000)
            completion()
        }
    }
}
