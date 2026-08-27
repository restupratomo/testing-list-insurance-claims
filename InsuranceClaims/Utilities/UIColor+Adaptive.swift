import UIKit

/// `UIColor.label` and friends only exist from iOS 13 onward. Since this app's
/// minimum deployment target is iOS 12, these fall back to fixed colors that
/// match Apple's iOS 12 system palette on older devices.
extension UIColor {
    static var adaptiveLabel: UIColor {
        if #available(iOS 13.0, *) {
            return .label
        }
        return .black
    }

    static var adaptiveSecondaryLabel: UIColor {
        if #available(iOS 13.0, *) {
            return .secondaryLabel
        }
        return UIColor(white: 0.42, alpha: 1)
    }

    static var adaptiveTertiaryLabel: UIColor {
        if #available(iOS 13.0, *) {
            return .tertiaryLabel
        }
        return UIColor(white: 0.6, alpha: 1)
    }

    static var adaptiveBackground: UIColor {
        if #available(iOS 13.0, *) {
            return .systemBackground
        }
        return .white
    }

    static var adaptiveSeparator: UIColor {
        if #available(iOS 13.0, *) {
            return .separator
        }
        return UIColor(white: 0.85, alpha: 1)
    }
}
