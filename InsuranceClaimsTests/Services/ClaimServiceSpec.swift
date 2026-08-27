import Quick
import Nimble
@testable import InsuranceClaims

final class ClaimServiceSpec: QuickSpec {
    override func spec() {
        describe("ClaimService") {
            var apiClient: APIClientMock!
            var cache: ClaimCacheMock!
            var sut: ClaimService!

            beforeEach {
                apiClient = APIClientMock()
                cache = ClaimCacheMock()
                sut = ClaimService(apiClient: apiClient, cache: cache)
            }

            context("when the requested page is already cached") {
                let cachedClaim = Claim(claimantId: 1, id: 1, title: "Cached claim", description: "From cache")

                beforeEach {
                    cache.store([cachedClaim], forPage: 1)
                }

                it("returns the cached claims without hitting the network") {
                    var result: [Claim]?
                    sut.fetchClaims(page: 1) { outcome in
                        result = try? outcome.get()
                    }

                    expect(result).to(equal([cachedClaim]))
                    expect(apiClient.requestedEndpoints).to(beEmpty())
                }
            }

            context("when the requested page is not cached") {
                let fetchedClaim = Claim(claimantId: 2, id: 2, title: "Fresh claim", description: "From network")

                beforeEach {
                    apiClient.resultToReturn = .success([fetchedClaim])
                }

                it("fetches from the network and stores the result in the cache") {
                    var result: [Claim]?
                    sut.fetchClaims(page: 1) { outcome in
                        result = try? outcome.get()
                    }

                    expect(result).to(equal([fetchedClaim]))
                    expect(cache.storeCallCount).to(equal(1))
                    expect(cache.claims(forPage: 1)).to(equal([fetchedClaim]))
                }
            }

            context("when the network request fails") {
                beforeEach {
                    apiClient.resultToReturn = .failure(.server(statusCode: 500))
                }

                it("propagates the failure and does not touch the cache") {
                    var receivedError: NetworkError?
                    sut.fetchClaims(page: 1) { outcome in
                        if case .failure(let error) = outcome {
                            receivedError = error
                        }
                    }

                    expect(receivedError).to(equal(.server(statusCode: 500)))
                    expect(cache.storeCallCount).to(equal(0))
                }
            }
        }
    }
}
