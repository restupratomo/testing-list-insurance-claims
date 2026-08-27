import IQKeyboardManagerSwift
import Nimble
import Quick

/// Verifies the app-wide keyboard-avoidance configuration set in
/// AppDelegate. These specs run hosted inside the real app process (see
/// TEST_HOST/BUNDLE_LOADER), so `application(_:didFinishLaunchingWithOptions:)`
/// has already executed by the time any example runs — no need to invoke
/// AppDelegate manually.
final class KeyboardManagerConfigurationSpec: QuickSpec {
    override class func spec() {
        describe("IQKeyboardManager configuration") {
            it("is enabled, so no text field/view is ever left hidden behind the keyboard") {
                expect(IQKeyboardManager.shared.enable).to(beTrue())
            }

            it("resigns the keyboard when the user taps outside the focused field") {
                expect(IQKeyboardManager.shared.shouldResignOnTouchOutside).to(beTrue())
            }

            it("never ships with debug logging enabled") {
                // IQKeyboardManager's debug mode prints view-hierarchy and
                // responder-chain details to the console on every keyboard
                // event — a hardening requirement, not just noise.
                expect(IQKeyboardManager.shared.enableDebugging).to(beFalse())
            }
        }
    }
}
