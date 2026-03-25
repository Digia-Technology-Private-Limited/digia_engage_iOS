import SwiftUI

enum DigiaFallbackMode {
    case inline
    case modal
    case bottomSheet
}

@MainActor
struct FallbackExperienceView: View {
    let payload: InAppPayload
    let mode: DigiaFallbackMode
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(titleText)
                    .font(.headline)
                Spacer()
                Button("Close", action: onDismiss)
                    .font(.caption)
            }

            Text("campaign_id: \(payload.id)")
                .font(.caption.monospaced())

            Text("type: \(payload.content.type)")
                .font(.caption)

            if let placement = payload.content.placementKey {
                Text("placement: \(placement)")
                    .font(.caption)
            }

            if let title = payload.content.title {
                Text(title)
                    .font(.body.weight(.semibold))
            } else if let text = payload.content.text {
                Text(text)
                    .font(.body)
            } else {
                Text("Renderer not wired yet. Payload is available and routed correctly.")
                    .font(.body)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 8)
        )
        .padding(mode == .modal ? 24 : 0)
        .frame(maxWidth: mode == .modal ? 420 : nil)
    }

    private var titleText: String {
        switch mode {
        case .inline:
            return "Digia Slot"
        case .modal:
            return "Digia Modal"
        case .bottomSheet:
            return "Digia Bottom Sheet"
        }
    }
}
