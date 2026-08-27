import Foundation
import Localize_Swift

/// Errors surfaced by the networking layer, in terms the UI can present directly.
enum NetworkError: Error, Equatable {
    case invalidURL
    case noConnection
    case server(statusCode: Int)
    case decoding
    case sslPinningFailed
    case unknown

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "network_error.invalid_url".localized()
        case .noConnection:
            return "network_error.no_connection".localized()
        case .server(let statusCode):
            return "network_error.server".localizedFormat(statusCode)
        case .decoding:
            return "network_error.decoding".localized()
        case .sslPinningFailed:
            return "network_error.ssl_pinning_failed".localized()
        case .unknown:
            return "network_error.unknown".localized()
        }
    }
}
