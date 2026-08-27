import Quick
import Nimble
import UIKit
@testable import InsuranceClaims

private struct MockOSVersionChecker: OSVersionChecking {
    let isIOS13OrLater: Bool
}

final class UIColorAdaptiveSpec: QuickSpec {
    override class func spec() {
        describe("UIColor adaptive palette") {
            afterEach {
                AdaptiveColorEnvironment.osVersionChecker = RealOSVersionChecker()
            }

            context("on iOS 13 and later") {
                beforeEach {
                    AdaptiveColorEnvironment.osVersionChecker = MockOSVersionChecker(isIOS13OrLater: true)
                }

                it("uses the dynamic system label color") {
                    guard #available(iOS 13.0, *) else { return }
                    expect(UIColor.adaptiveLabel).to(equal(.label))
                }

                it("uses the dynamic system secondary label color") {
                    guard #available(iOS 13.0, *) else { return }
                    expect(UIColor.adaptiveSecondaryLabel).to(equal(.secondaryLabel))
                }

                it("uses the dynamic system tertiary label color") {
                    guard #available(iOS 13.0, *) else { return }
                    expect(UIColor.adaptiveTertiaryLabel).to(equal(.tertiaryLabel))
                }

                it("uses the dynamic system background color") {
                    guard #available(iOS 13.0, *) else { return }
                    expect(UIColor.adaptiveBackground).to(equal(.systemBackground))
                }

                it("uses a visible system grey separator") {
                    guard #available(iOS 13.0, *) else { return }
                    expect(UIColor.adaptiveSeparator).to(equal(.systemGray4))
                }
            }

            context("on iOS 12, where the dynamic system colors don't exist") {
                beforeEach {
                    AdaptiveColorEnvironment.osVersionChecker = MockOSVersionChecker(isIOS13OrLater: false)
                }

                it("falls back to a fixed black label color") {
                    expect(UIColor.adaptiveLabel).to(equal(.black))
                }

                it("falls back to a fixed grey secondary label color") {
                    expect(UIColor.adaptiveSecondaryLabel).to(equal(UIColor(white: 0.42, alpha: 1)))
                }

                it("falls back to a fixed grey tertiary label color") {
                    expect(UIColor.adaptiveTertiaryLabel).to(equal(UIColor(white: 0.6, alpha: 1)))
                }

                it("falls back to a fixed white background color") {
                    expect(UIColor.adaptiveBackground).to(equal(.white))
                }

                it("falls back to a fixed grey separator color") {
                    expect(UIColor.adaptiveSeparator).to(equal(UIColor(white: 0.78, alpha: 1)))
                }
            }
        }
    }
}
