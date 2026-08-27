import Foundation

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
            return "The request could not be built. Please try again."
        case .noConnection:
            return "No internet connection. Please check your network and try again."
        case .server(let statusCode):
            return "The server returned an error (code \(statusCode)). Please try again later."
        case .decoding:
            return "We couldn't read the claims data returned by the server."
        case .sslPinningFailed:
            return "We couldn't verify the server's identity. For your security the request was blocked."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}
