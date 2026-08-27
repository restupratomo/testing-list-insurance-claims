import Quick
import Nimble
@testable import InsuranceClaims

final class ClaimDetailViewControllerSpec: QuickSpec {
    override class func spec() {
        describe("ClaimDetailViewController") {
            it("takes its navigation title from the view model") {
                let claim = Claim(claimantId: 1, id: 5, title: "Water damage", description: "Pipe burst")
                let sut = ClaimDetailViewController(viewModel: ClaimDetailViewModel(claim: claim))

                expect(sut.title).to(equal("Claim #5"))
            }
        }
    }
}
