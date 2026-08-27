import Foundation

/// A colour expressed as hue, saturation and lightness.
///
/// *"Ditch hex for HSL"* (Refactoring UI, p138). Colours that have a lot in common visually
/// look nothing alike as RGB triplets, which makes a palette impossible to reason about. In HSL
/// a ramp is obvious: same hue, walk the lightness.
///
/// Deliberately **HSL, not HSB.** The book calls this out (p141) and SwiftUI only offers
/// `Color(hue:saturation:brightness:)`, which is HSB — in HSB, 100% brightness is only white
/// when saturation is 0. Using HSB where HSL is meant silently washes out every light shade, so
/// the conversion below is written out rather than borrowed from SwiftUI.
public struct HSL: Sendable, Equatable, Hashable {
    /// Degrees, 0-360.
    public var hue: Double
    /// 0-1.
    public var saturation: Double
    /// 0-1. 0 is black, 1 is white, 0.5 is the pure hue.
    public var lightness: Double
    /// 0-1.
    public var alpha: Double

    public init(_ hue: Double, _ saturation: Double, _ lightness: Double, alpha: Double = 1) {
        self.hue = hue.truncatingRemainder(dividingBy: 360)
        self.saturation = min(max(saturation, 0), 1)
        self.lightness = min(max(lightness, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    /// sRGB components in 0-1, for handing to a colour type.
    public var rgb: (red: Double, green: Double, blue: Double) {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hPrime = hue / 60
        let x = c * (1 - abs(hPrime.truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - c / 2

        let (r1, g1, b1): (Double, Double, Double)
        switch hPrime {
        case ..<1:  (r1, g1, b1) = (c, x, 0)
        case ..<2:  (r1, g1, b1) = (x, c, 0)
        case ..<3:  (r1, g1, b1) = (0, c, x)
        case ..<4:  (r1, g1, b1) = (0, x, c)
        case ..<5:  (r1, g1, b1) = (x, 0, c)
        default:    (r1, g1, b1) = (c, 0, x)
        }
        return (r1 + m, g1 + m, b1 + m)
    }

    /// WCAG 2.1 relative luminance.
    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = rgb
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    /// WCAG contrast ratio against another colour, 1...21.
    public func contrastRatio(against other: HSL) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    public func withAlpha(_ alpha: Double) -> HSL {
        HSL(hue, saturation, lightness, alpha: alpha)
    }

    /// The nearest perceptually bright hue: 60 (yellow), 180 (cyan) or 300 (magenta).
    ///
    /// *"Don't let lightness kill your saturation"* (p152): every hue has an inherent perceived
    /// brightness, so a colour can be lightened by rotating toward a bright hue instead of only
    /// raising lightness — which keeps its intensity instead of walking it toward white.
    var nearestBrightHue: Double {
        [60.0, 180.0, 300.0].min { abs(angularDistance(hue, $0)) < abs(angularDistance(hue, $1)) }!
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        let raw = (b - a).truncatingRemainder(dividingBy: 360)
        if raw > 180 { return raw - 360 }
        if raw < -180 { return raw + 360 }
        return raw
    }

    /// Rotates the hue toward `target` by `amount` (0-1 of the way).
    ///
    /// Capped at 24 degrees by the caller: the book warns that beyond about 20-30 degrees it
    /// reads as a different colour rather than a lighter one.
    func rotatingHue(toward target: Double, by amount: Double) -> HSL {
        let delta = angularDistance(hue, target) * amount
        return HSL(hue + delta, saturation, lightness, alpha: alpha)
    }
}
