@MainActor
public protocol DigiaCEPDelegate: AnyObject {
    func onCampaignTriggered(_ payload: InAppPayload)
    func onCampaignInvalidated(_ campaignID: String)
}
