import Foundation

/// Intercepts every request made through a `URLSession` configured with it,
/// so networking specs can exercise `APIClient` without touching the network.
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data?)) = { request in
        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, nil)
    }

    /// When set, `startLoading` fails the request with this error instead of
    /// calling `handler`, simulating a transport-level failure (e.g. no
    /// connection) rather than a server response.
    static var transportError: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let transportError = Self.transportError {
            client?.urlProtocol(self, didFailWithError: transportError)
            return
        }

        let (response, data) = Self.handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
