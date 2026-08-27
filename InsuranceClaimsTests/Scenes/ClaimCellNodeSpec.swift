import Quick
import Nimble
import AsyncDisplayKit
@testable import InsuranceClaims

final class ClaimCellNodeSpec: QuickSpec {
    override class func spec() {
        describe("ClaimCellNode") {
            let claim = Claim(claimantId: 3, id: 9, title: "vehicle damage", description: "Hit from behind at a light")

            it("builds a layout spec that fits the available width") {
                let node = ClaimCellNode(claim: claim)
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
