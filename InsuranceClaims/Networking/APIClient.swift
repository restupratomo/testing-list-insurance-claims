import Alamofire
import Foundation

/// Thin wrapper around Alamofire that performs a request and decodes the
/// JSON response, translating transport-level failures into `NetworkError`.
protocol APIClientProtocol {
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        decodingTo type: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    )
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: Session

    /// - Parameter pinnedHost: when set, Alamofire will refuse to complete any
    ///   request to this host unless its certificate matches the pin in
    ///   `SSLPinningManager`.
    init(baseURL: URL, pinnedHost: String? = nil) {
        self.baseURL = baseURL

        if let pinnedHost = pinnedHost {
            self.session = Session(serverTrustManager: SSLPinningManager.makeServerTrustManager(pinnedHost: pinnedHost))
        } else {
            self.session = Session()
        }
    }

    /// Test-only seam: lets specs inject a `Session` running against a
    /// stubbed `URLProtocol` instead of the network.
    init(session: Session, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        decodingTo type: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        guard let url = endpoint.url(relativeTo: baseURL) else {
            completion(.failure(.invalidURL))
            return
        }

        session.request(url)
            .validate()
            .responseDecodable(of: T.self) { response in
                switch response.result {
                case .success(let decoded):
                    completion(.success(decoded))
                case .failure(let error):
                    completion(.failure(self.networkError(for: error, response: response.response)))
                }
            }
    }

    /// Internal rather than private so specs can drive every branch directly
    /// with synthetic `AFError` values — several of these (a genuine SSL pin
    /// mismatch, an unrecognized Alamofire failure) can't be triggered
    /// through a stubbed `URLProtocol`, since that bypasses the real TLS
    /// handshake entirely.
    func networkError(for error: AFError, response: HTTPURLResponse?) -> NetworkError {
        if case .serverTrustEvaluationFailed = error {
            return .sslPinningFailed
        }
        if case .responseSerializationFailed = error {
            return .decoding
        }
        if let statusCode = response?.statusCode, !(200...299).contains(statusCode) {
            return .server(statusCode: statusCode)
        }
        if error.isSessionTaskError {
            return .noConnection
        }
        return .unknown
    }
}
