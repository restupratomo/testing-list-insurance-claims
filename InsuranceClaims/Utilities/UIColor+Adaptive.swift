import UIKit

/// Abstracts an additional runtime check alongside `#available(iOS 13.0, *)`
/// so specs can force the iOS 12 fallback branches below to run
/// deterministically, rather than that code only ever executing on an
/// actual iOS 12 device or simulator.
protocol OSVersionChecking {
    var isIOS13OrLater: Bool { get }
}

struct RealOSVersionChecker: OSVersionChecking {
    var isIOS13OrLater: Bool { true }
}

/// Test-only seam: specs swap this in for a mock, then restore
/// `RealOSVersionChecker()` afterward.
enum AdaptiveColorEnvironment {
    static var osVersionChecker: OSVersionChecking = RealOSVersionChecker()
}

/// `UIColor.label` and friends only exist from iOS 13 onward. Since this app's
/// minimum deployment target is iOS 12, these fall back to fixed colors that
/// match Apple's iOS 12 system palette on older devices.
extension UIColor {
    static var adaptiveLabel: UIColor {
        if #available(iOS 13.0, *), AdaptiveColorEnvironment.osVersionChecker.isIOS13OrLater {
            return .label
        }
        return .black
    }

    static var adaptiveSecondaryLabel: UIColor {
        if #available(iOS 13.0, *), AdaptiveColorEnvironment.osVersionChecker.isIOS13OrLater {
            return .secondaryLabel
        }
        return UIColor(white: 0.42, alpha: 1)
    }

    static var adaptiveTertiaryLabel: UIColor {
        if #available(iOS 13.0, *), AdaptiveColorEnvironment.osVersionChecker.isIOS13OrLater {
            return .tertiaryLabel
        }
        return UIColor(white: 0.6, alpha: 1)
    }

    static var adaptiveBackground: UIColor {
        if #available(iOS 13.0, *), AdaptiveColorEnvironment.osVersionChecker.isIOS13OrLater {
            return .systemBackground
        }
        return .white
    }

    /// A clearly visible grey row divider. Deliberately not `.separator`,
    /// which iOS renders as a near-invisible hairline by design — this list
    /// wants a divider the user actually notices between rows.
    static var adaptiveSeparator: UIColor {
        if #available(iOS 13.0, *), AdaptiveColorEnvironment.osVersionChecker.isIOS13OrLater {
            return .systemGray4
        }
        return UIColor(white: 0.78, alpha: 1)
    }
}
