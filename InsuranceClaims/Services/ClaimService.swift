import Foundation

final class ClaimService: ClaimServiceProtocol {
    private let apiClient: APIClientProtocol
    private let cache: ClaimCacheProtocol

    init(apiClient: APIClientProtocol, cache: ClaimCacheProtocol) {
        self.apiClient = apiClient
        self.cache = cache
    }

    func fetchClaims(page: Int, completion: @escaping (Result<[Claim], NetworkError>) -> Void) {
        if let cached = cache.claims(forPage: page) {
            completion(.success(cached))
            return
        }

        let endpoint = Endpoint.claims(page: page, pageSize: claimsPageSize)
        apiClient.request(endpoint, decodingTo: [Claim].self) { [weak self] result in
            switch result {
            case .success(let claims):
                self?.cache.store(claims, forPage: page)
                completion(.success(claims))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
