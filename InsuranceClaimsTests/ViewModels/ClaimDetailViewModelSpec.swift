import Quick
import Nimble
@testable import InsuranceClaims

final class ClaimDetailViewModelSpec: QuickSpec {
    override class func spec() {
        describe("ClaimDetailViewModel") {
            let claim = Claim(claimantId: 7, id: 42, title: "vehicle damage", description: "Hit from behind")
            let sut = ClaimDetailViewModel(claim: claim)

            it("exposes the claim's id as the screen title") {
                expect(sut.screenTitle).to(equal("Claim #42"))
            }

            it("capitalizes the claim title for display") {
                expect(sut.title).to(equal("Vehicle Damage"))
            }

            it("exposes the full, untruncated description") {
                expect(sut.description).to(equal("Hit from behind"))
            }

            it("formats claim and claimant ids into a single metadata line") {
                expect(sut.metadata).to(equal("Claim ID: 42    Claimant ID: 7"))
            }
        }
    }
}
