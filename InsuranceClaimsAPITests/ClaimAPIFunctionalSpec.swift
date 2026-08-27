import Quick
import Nimble
@testable import InsuranceClaims

/// Functional test that exercises the real JSONPlaceholder API end-to-end,
/// as opposed to the unit specs which stub the network entirely. Requires
/// network access; skipped assertions here would indicate an environment
/// problem rather than a regression in app code.
final class ClaimAPIFunctionalSpec: QuickSpec {
    override func spec() {
        describe("the live claims API") {
            var apiClient: APIClient!

            beforeEach {
                apiClient = APIClient(baseURL: AppEnvironment.claimsBaseURL, pinnedHost: AppEnvironment.claimsHost)
            }

            it("returns exactly one page of claims for the requested page size") {
                var received: [Claim]?
                var receivedError: NetworkError?

                waitUntil(timeout: .seconds(10)) { done in
                    apiClient.request(
                        Endpoint.claims(page: 1, pageSize: claimsPageSize),
                        decodingTo: [Claim].self
                    ) { result in
                        switch result {
                        case .success(let claims): received = claims
                        case .failure(let error): receivedError = error
                        }
                        done()
                    }
                }

                expect(receivedError).to(beNil())
                expect(received).toNot(beNil())
                expect(received?.count).to(equal(claimsPageSize))
            }

            it("returns claims with all fields populated") {
                var received: [Claim]?

                waitUntil(timeout: .seconds(10)) { done in
                    apiClient.request(
                        Endpoint.claims(page: 1, pageSize: 1),
                        decodingTo: [Claim].self
                    ) { result in
                        received = try? result.get()
                        done()
                    }
                }

                let claim = received?.first
                expect(claim).toNot(beNil())
                expect(claim?.title.isEmpty).to(beFalse())
                expect(claim?.description.isEmpty).to(beFalse())
                expect(claim?.id).to(beGreaterThan(0))
                expect(claim?.claimantId).to(beGreaterThan(0))
            }

            it("advances to different claims on subsequent pages") {
                var firstPage: [Claim]?
                var secondPage: [Claim]?

                waitUntil(timeout: .seconds(10)) { done in
                    apiClient.request(Endpoint.claims(page: 1, pageSize: 10), decodingTo: [Claim].self) { result in
                        firstPage = try? result.get()
                        done()
                    }
                }

                waitUntil(timeout: .seconds(10)) { done in
                    apiClient.request(Endpoint.claims(page: 2, pageSize: 10), decodingTo: [Claim].self) { result in
                        secondPage = try? result.get()
                        done()
                    }
                }

                let firstIds = Set((firstPage ?? []).map { $0.id })
                let secondIds = Set((secondPage ?? []).map { $0.id })
                expect(firstIds.isDisjoint(with: secondIds)).to(beTrue())
            }
        }
    }
}
