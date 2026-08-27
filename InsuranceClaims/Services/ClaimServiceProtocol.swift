import Foundation

/// Number of claims requested per page throughout the app.
let claimsPageSize = 10

/// Fetches insurance claims, transparently serving cached pages when they are
/// still fresh and falling back to the network otherwise.
protocol ClaimServiceProtocol {
    func fetchClaims(page: Int, completion: @escaping (Result<[Claim], NetworkError>) -> Void)
}
