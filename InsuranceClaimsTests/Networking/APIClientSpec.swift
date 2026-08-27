import Alamofire
@testable import InsuranceClaims
import Nimble
import Quick

final class APIClientSpec: QuickSpec {
    override class func spec() {
        describe("APIClient") {
            var sut: APIClient!
            let baseURL = URL(string: "https://example.com")!

            func makeClient() -> APIClient {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [StubURLProtocol.self]
                let session = Session(configuration: configuration)
                return APIClient(session: session, baseURL: baseURL)
            }

            beforeEach {
                sut = makeClient()
            }

            context("initialization") {
                it("builds an unpinned session when no host is given to pin") {
                    let client = APIClient(baseURL: baseURL)
                    expect(client).toNot(beNil())
                }

                it("builds a pinned session when a host is given to pin") {
                    let client = APIClient(baseURL: baseURL, pinnedHost: "example.com")
                    expect(client).toNot(beNil())
                }
            }

            context("when the endpoint cannot be turned into a request URL") {
                it("completes with an invalidURL error and never touches the network") {
                    sut.urlBuilder = { _, _ in nil }

                    var result: Result<[Claim], NetworkError>?
                    sut.request(Endpoint.claims(page: 1, pageSize: 10), decodingTo: [Claim].self) { result = $0 }

                    expect(result).toNot(beNil())
                    if case .failure(let error) = result {
                        expect(error).to(equal(.invalidURL))
                    } else {
                        fail("expected a failure result")
                    }
                }
            }

            context("when the server returns a decodable, successful response") {
                it("completes with the decoded value") {
                    let json = Data("""
                    [{"userId":1,"id":2,"title":"Vehicle damage","body":"Hit from behind"}]
                    """.utf8)

                    StubURLProtocol.handler = { request in
                        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
                    }

                    var result: Result<[Claim], NetworkError>?
                    sut.request(Endpoint.claims(page: 1, pageSize: 10), decodingTo: [Claim].self) { result = $0 }

                    expect(result).toEventuallyNot(beNil())
                    expect(try? result?.get()).to(equal([
                        Claim(claimantId: 1, id: 2, title: "Vehicle damage", description: "Hit from behind")
                    ]))
                }
            }

            context("when the server returns a non-2xx status code") {
                it("completes with a server error carrying the status code") {
                    StubURLProtocol.handler = { request in
                        (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
                    }

                    var result: Result<[Claim], NetworkError>?
                    sut.request(Endpoint.claims(page: 1, pageSize: 10), decodingTo: [Claim].self) { result = $0 }

                    expect(result).toEventuallyNot(beNil())
                    if case .failure(let error) = result {
                        expect(error).to(equal(.server(statusCode: 500)))
                    } else {
                        fail("expected a failure result")
                    }
                }
            }

            context("when the server returns a 2xx response with unparseable JSON") {
                it("completes with a decoding error") {
                    let malformed = Data("not json".utf8)
                    StubURLProtocol.handler = { request in
                        (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, malformed)
                    }

                    var result: Result<[Claim], NetworkError>?
                    sut.request(Endpoint.claims(page: 1, pageSize: 10), decodingTo: [Claim].self) { result = $0 }

                    expect(result).toEventuallyNot(beNil())
                    if case .failure(let error) = result {
                        expect(error).to(equal(.decoding))
                    } else {
                        fail("expected a failure result")
                    }
                }
            }

            context("when the underlying transport fails") {
                afterEach {
                    StubURLProtocol.transportError = nil
                }

                it("completes with a noConnection error") {
                    StubURLProtocol.transportError = URLError(.notConnectedToInternet)

                    var result: Result<[Claim], NetworkError>?
                    sut.request(Endpoint.claims(page: 1, pageSize: 10), decodingTo: [Claim].self) { result = $0 }

                    expect(result).toEventuallyNot(beNil())
                    if case .failure(let error) = result {
                        expect(error).to(equal(.noConnection))
                    } else {
                        fail("expected a failure result")
                    }
                }
            }
        }

        // These map error branches directly, with AFError values built by hand:
        // a genuine SSL pin mismatch and Alamofire's own "none of the above"
        // failures can't be triggered through a stubbed URLProtocol, since
        // stubbing bypasses the real TLS handshake entirely.
        describe("APIClient.networkError(for:response:)") {
            var sut: APIClient!

            beforeEach {
                sut = APIClient(session: Session(), baseURL: URL(string: "https://example.com")!)
            }

            it("maps a server trust evaluation failure to sslPinningFailed") {
                let error = AFError.serverTrustEvaluationFailed(reason: .noRequiredEvaluator(host: "example.com"))
                expect(sut.networkError(for: error, response: nil)).to(equal(.sslPinningFailed))
            }

            it("maps a response serialization failure to decoding") {
                let error = AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength)
                expect(sut.networkError(for: error, response: nil)).to(equal(.decoding))
            }

            it("maps a non-2xx response status to a server error, regardless of the AFError case") {
                let error = AFError.explicitlyCancelled
                let response = HTTPURLResponse(
                    url: URL(string: "https://example.com")!,
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )
                expect(sut.networkError(for: error, response: response)).to(equal(.server(statusCode: 404)))
            }

            it("maps a session task failure to noConnection") {
                let error = AFError.sessionTaskFailed(error: URLError(.notConnectedToInternet))
                expect(sut.networkError(for: error, response: nil)).to(equal(.noConnection))
            }

            it("falls back to unknown for anything else") {
                let error = AFError.explicitlyCancelled
                expect(sut.networkError(for: error, response: nil)).to(equal(.unknown))
            }
        }
    }
}
