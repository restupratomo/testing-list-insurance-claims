import Quick
import Nimble
@testable import InsuranceClaims

final class ClaimCacheSpec: QuickSpec {
    override class func spec() {
        describe("ClaimCache") {
            var sut: ClaimCache!
            let claim = Claim(claimantId: 10, id: 20, title: "Water damage", description: "Pipe burst in the kitchen")

            afterEach {
                sut.invalidateAll()
            }

            context("with a normal time-to-live") {
                beforeEach {
                    sut = ClaimCache(timeToLive: 60)
                }

                it("returns nil for a page that was never stored") {
                    expect(sut.claims(forPage: 1)).to(beNil())
                }

                it("returns what was stored for that page") {
                    sut.store([claim], forPage: 1)
                    expect(sut.claims(forPage: 1)).to(equal([claim]))
                }

                it("keeps pages independent of one another") {
                    sut.store([claim], forPage: 1)
                    expect(sut.claims(forPage: 2)).to(beNil())
                }

                it("forgets a page after it is invalidated") {
                    sut.store([claim], forPage: 1)
                    sut.invalidate(page: 1)
                    expect(sut.claims(forPage: 1)).to(beNil())
                }
            }

            context("once the time-to-live has elapsed") {
                it("treats the cached page as empty so it gets refreshed") {
                    sut = ClaimCache(timeToLive: -1)
                    sut.store([claim], forPage: 1)
                    expect(sut.claims(forPage: 1)).to(beNil())
                }
            }
        }
    }
}
