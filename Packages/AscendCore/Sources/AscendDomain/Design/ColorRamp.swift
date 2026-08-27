import Foundation

/// Nine fixed shades of one hue, 100 (lightest) to 900 (darkest).
///
/// *"You need more colors than you think"* (p142) and *"Define your shades up front"* (p148).
/// Nine because it divides cleanly and the book's fill-in-the-gaps method lands on it: pick
/// 500, then the edges, then 300/700, then the rest.
///
/// Generated rather than hand-typed, but generated **once**, into stored values — the book's
/// actual warning is against calling `lighten()`/`darken()` at the point of use, which is how
/// you end up with thirty-five slightly different blues. A ramp is a closed set of nine.
public struct ColorRamp: Sendable, Equatable {
    public let shades: [Int: HSL]

    public subscript(_ shade: Int) -> HSL {
        shades[shade] ?? shades[500]!
    }

    public var s100: HSL { self[100] }
    public var s200: HSL { self[200] }
    public var s300: HSL { self[300] }
    public var s400: HSL { self[400] }
    public var s500: HSL { self[500] }
    public var s600: HSL { self[600] }
    public var s700: HSL { self[700] }
    public var s800: HSL { self[800] }
    public var s900: HSL { self[900] }

    /// Builds a ramp from a base hue.
    ///
    /// Two rules from the book are baked in:
    ///
    /// - **Saturation rises as lightness leaves 50%** (p152). In HSL the effect of saturation
    ///   weakens toward black and white, so holding saturation flat makes both ends look washed
    ///   out. `saturationLift` is how much is added at the extremes.
    /// - **Light shades rotate toward the nearest bright hue** (p155), capped at 24 degrees, so
    ///   they read as brighter rather than as closer to white.
    public init(hue: Double,
                baseSaturation: Double,
                lightest: Double = 0.94,
                base: Double = 0.56,
                darkest: Double = 0.10,
                saturationLift: Double = 0.16,
                hueRotation: Double = 0.35) {
        // 100 is lightest, 900 darkest, 500 the base — so lightness falls as the number rises.
        let stops: [(Int, Double)] = [
            (100, lightest),
            (200, lightest - (lightest - base) * 0.28),
            (300, lightest - (lightest - base) * 0.52),
            (400, lightest - (lightest - base) * 0.78),
            (500, base),
            (600, base - (base - darkest) * 0.24),
            (700, base - (base - darkest) * 0.48),
            (800, base - (base - darkest) * 0.74),
            (900, darkest),
        ]

        var built: [Int: HSL] = [:]
        let brightHue = HSL(hue, baseSaturation, base).nearestBrightHue
        for (shade, lightness) in stops {
            let distanceFrom50 = abs(lightness - 0.5) / 0.5
            let saturation = min(1, baseSaturation + saturationLift * distanceFrom50)
            var colour = HSL(hue, saturation, lightness)
            if lightness > base {
                // Only the light end gets the rotation; darkening by hue would pull colours
                // toward red/green/blue and muddy them.
                let amount = hueRotation * ((lightness - base) / max(0.0001, lightest - base))
                colour = colour.rotatingHue(toward: brightHue, by: min(amount, 24.0 / 180.0))
            }
            built[shade] = colour
        }
        self.shades = built
    }
}
