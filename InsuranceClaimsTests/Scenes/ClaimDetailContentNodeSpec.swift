import AsyncDisplayKit
@testable import InsuranceClaims
import Nimble
import Quick

final class ClaimDetailContentNodeSpec: QuickSpec {
    override class func spec() {
        describe("ClaimDetailContentNode") {
            let claim = Claim(claimantId: 3, id: 9, title: "vehicle damage", description: "Hit from behind at a light")
            let viewModel = ClaimDetailViewModel(claim: claim)

            it("builds a layout spec that fits the available width") {
                let node = ClaimDetailContentNode(viewModel: viewModel)
                let constrainedSize = ASSizeRange(
                    min: CGSize(width: 320, height: 0),
                    max: CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
                )

                let spec = node.layoutSpecThatFits(constrainedSize)

                expect(spec).toNot(beNil())
            }
        }
    }
}
