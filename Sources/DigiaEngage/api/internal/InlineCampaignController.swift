import SwiftUI

@MainActor
final class InlineCampaignController: ObservableObject {
    @Published private var campaigns: [String: InAppPayload] = [:]

    var onEvent: ((DigiaExperienceEvent, InAppPayload) -> Void)?

    func getCampaign(_ placementKey: String) -> InAppPayload? {
        campaigns[placementKey]
    }

    func setCampaign(_ placementKey: String, payload: InAppPayload) {
        campaigns[placementKey] = payload
    }

    func removeCampaign(_ campaignID: String) {
        campaigns = campaigns.filter { placementKey, payload in
            placementKey != campaignID && payload.id != campaignID
        }
    }

    func dismissCampaign(_ placementKey: String) {
        campaigns.removeValue(forKey: placementKey)
    }

    func clear() {
        campaigns.removeAll()
    }
}
