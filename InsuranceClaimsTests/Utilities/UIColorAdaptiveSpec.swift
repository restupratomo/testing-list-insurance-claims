import Quick
import Nimble
import UIKit
@testable import InsuranceClaims

final class UIColorAdaptiveSpec: QuickSpec {
    override class func spec() {
        describe("UIColor adaptive palette") {
            it("provides a label color") {
                expect(UIColor.adaptiveLabel).toNot(beNil())
            }

            it("provides a secondary label color") {
                expect(UIColor.adaptiveSecondaryLabel).toNot(beNil())
            }

            it("provides a tertiary label color") {
                expect(UIColor.adaptiveTertiaryLabel).toNot(beNil())
            }

            it("provides a background color") {
                expect(UIColor.adaptiveBackground).toNot(beNil())
            }

            it("provides a separator color") {
                expect(UIColor.adaptiveSeparator).toNot(beNil())
            }
        }
    }
}
