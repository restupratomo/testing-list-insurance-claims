import Foundation
@testable import InsuranceClaims

final class APIClientMock: APIClientProtocol {
    var resultToReturn: Result<[Claim], NetworkError> = .success([])
    private(set) var requestedEndpoints: [Endpoint] = []

    func request<T>(
        _ endpoint: Endpoint,
        decodingTo type: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) where T: Decodable {
        requestedEndpoints.append(endpoint)
        // The mock only ever stands in for `[Claim]` responses in these tests.
        guard let result = resultToReturn as? Result<T, NetworkError> else {
            fatalError("APIClientMock only supports decoding [Claim] in these tests")
        }
        completion(result)
    }
}
