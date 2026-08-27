@testable import InsuranceClaims
import Nimble
import Quick

final class NetworkErrorSpec: QuickSpec {
    override class func spec() {
        describe("NetworkError.userMessage") {
            it("has a non-empty, distinct message for every case") {
                let cases: [NetworkError] = [
                    .invalidURL,
                    .noConnection,
                    .server(statusCode: 404),
                    .decoding,
                    .sslPinningFailed,
                    .unknown
                ]

                let messages = cases.map { $0.userMessage }
                expect(messages).to(allPass { !($0 ?? "").isEmpty })
                expect(Set(messages).count).to(equal(cases.count))
            }

            it("includes the status code in the server error message") {
                expect(NetworkError.server(statusCode: 503).userMessage).to(contain("503"))
            }
        }
    }
}
