import SwiftUI
import UIKit

@MainActor
struct InternalTextLabel: UIViewRepresentable {
    let attributedText: NSAttributedString
    let alignment: NSTextAlignment
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let clipsToBounds: Bool
    let expandToAvailableWidth: Bool

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributedText
        label.textAlignment = alignment
        label.numberOfLines = numberOfLines
        label.lineBreakMode = lineBreakMode
        label.clipsToBounds = clipsToBounds
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let height = proposal.height ?? .greatestFiniteMagnitude
        uiView.preferredMaxLayoutWidth = width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: height))
        let resolvedWidth = expandToAvailableWidth ? width : min(width, fitted.width)
        return CGSize(width: resolvedWidth, height: fitted.height)
    }
}
