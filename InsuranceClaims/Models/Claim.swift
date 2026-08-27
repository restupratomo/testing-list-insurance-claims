import Foundation

/// A single insurance claim record, as returned by the claims API.
struct Claim: Codable, Equatable {
    let claimantId: Int
    let id: Int
    let title: String
    let description: String

    private enum CodingKeys: String, CodingKey {
        case claimantId = "userId"
        case id
        case title
        case description = "body"
    }
}
