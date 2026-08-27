import Foundation
import Localize_Swift

/// Presents a single claim's full details. Kept trivial on purpose: the data
/// is already in memory by the time the user reaches this screen, so there is
/// nothing asynchronous to coordinate.
final class ClaimDetailViewModel {
    let claim: Claim

    init(claim: Claim) {
        self.claim = claim
    }

    var screenTitle: String {
        "claim_detail.title".localizedFormat(claim.id)
    }

    var title: String { claim.title.capitalized }
    var description: String { claim.description }

    var metadata: String {
        "claim_detail.metadata".localizedFormat(claim.id, claim.claimantId)
    }
}
