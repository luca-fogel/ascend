import Foundation

/// Every colour in Ascend, as data.
///
/// It lives in the domain layer rather than beside the SwiftUI views for one reason: it can be
/// tested. *"Accessible doesn't have to mean ugly"* (Refactoring UI, p162) gives concrete
/// numbers — 4.5:1 for text under ~18px, 3:1 above — and `PaletteContrastTests` asserts every
/// text-on-surface pairing meets them. A palette that is only a list of colours in a view file
/// is a palette whose accessibility is a matter of opinion.
public enum Palette {

    // MARK: - Greys
    //
    // *"Greys don't have to be grey"* (p158): true grey is 0% saturation and looks lifeless.
    // These are saturated toward 220 degrees, so the whole interface reads cool — which suits a
    // dark HUD, and makes the warm domain accents (orange, red) pop against it.
    //
    // Ten shades, not four. *"You need more colors than you think"* (p142): three or four reads
    // like plenty until you want something a shade darker than one and lighter than the next.
    public static let grey = ColorRamp(hue: 220,
                                       baseSaturation: 0.14,
                                       lightest: 0.96,
                                       base: 0.52,
                                       darkest: 0.055,
                                       saturationLift: 0.10,
                                       hueRotation: 0)

    /// One step below `grey.s900`, for the app background: the deepest surface in the app, so
    /// that every panel can be *lighter* than its background. *"Even flat designs can have
    /// depth"* (p190) — lighter reads as closer.
    public static let canvas = HSL(222, 0.24, 0.042)

    // MARK: - Text
    //
    // *"Don't use grey text on colored backgrounds"* (p42) is the rule that changed most here.
    // These were previously `Color.white.opacity(0.62)` and similar. Reducing opacity does
    // lower contrast, but it also drains saturation and lets whatever is behind show through,
    // so the text reads dull and faintly disabled. Each of these is now a hand-picked colour
    // sharing the greys' hue, adjusted on saturation and lightness until it sat right.
    //
    // Three, not five. *"Size isn't everything"* (p38): a dark colour for primary, a mid for
    // secondary, a lighter one for tertiary is all UI work needs.
    public static let textPrimary = HSL(220, 0.16, 0.97)
    public static let textSecondary = HSL(220, 0.13, 0.70)
    public static let textTertiary = HSL(220, 0.11, 0.50)
    /// For text sitting on a saturated *dark* fill, e.g. inside a primary button.
    public static let textOnAccent = HSL(220, 0.30, 0.99)

    /// For text on a high-brightness fill such as gold.
    ///
    /// Gold cannot carry white text: the contrast test measured 3.69:1 even two shades down the
    /// ramp, and darkening it further turns it brown. This is the perceived-brightness effect
    /// from p154 -- yellow is far brighter than blue at identical HSL lightness -- and the
    /// book's own answer on p164 is to flip the contrast rather than fight it.
    public static let textOnBright = HSL(40, 0.62, 0.11)

    // MARK: - Surfaces
    //
    // Three elevations, each lighter than the one beneath.
    public static let surface = HSL(220, 0.19, 0.095)
    public static let surfaceRaised = HSL(220, 0.17, 0.135)
    public static let surfaceHighest = HSL(220, 0.15, 0.185)

    /// The lighter top edge of a raised panel. *"Emulate a light source"* (p172): light comes
    /// from above, so the upward-facing edge catches it. Hand-picked rather than a translucent
    /// white, which the book warns sucks the saturation out of what is underneath.
    public static let topHighlight = HSL(220, 0.18, 0.26)
    /// Used sparingly — see *"Use fewer borders"* (p238).
    public static let hairline = HSL(220, 0.16, 0.20)

    /// The border of a text input.
    ///
    /// One of the few places a border is the right answer. *UI Design Principles* (Filipiuk,
    /// p140) is explicit: a field with a fill and a shadow and no border stops looking like a
    /// field and starts looking like a button, which is a confusing thing to put in a form. So
    /// inputs keep a visible edge even though every panel in the app lost theirs.
    public static let inputBorder = HSL(220, 0.18, 0.26)
    public static var inputBorderFocused: HSL { accent[400] }

    /// Shadow colour.
    ///
    /// **Not pure black** (Filipiuk p116): `#000000` reads unnatural, because nothing in the real
    /// world casts a pure black shadow. This is the dark end of the grey ramp instead, so shadows
    /// share the interface's cool temperature.
    public static let shadow = HSL(224, 0.45, 0.020)

    /// A shadow tinted with an element's own colour.
    ///
    /// Filipiuk p117: a coloured shadow under a coloured element makes a design pop in a way a
    /// neutral one cannot. Reserved for filled buttons; everywhere else it would be noise.
    public static func shadow(for ramp: ColorRamp) -> HSL {
        let base = ramp[600]
        return HSL(base.hue, min(1, base.saturation * 0.9), 0.10)
    }

    // MARK: - Brand and semantics
    public static let accent = ColorRamp(hue: 224, baseSaturation: 0.82, base: 0.60)
    public static let health = ColorRamp(hue: 352, baseSaturation: 0.78, base: 0.60)
    public static let gold = ColorRamp(hue: 42, baseSaturation: 0.88, base: 0.58)
    public static let success = ColorRamp(hue: 152, baseSaturation: 0.66, base: 0.46)

    // MARK: - Skill domains
    //
    // One ramp per domain, so a badge, a ring and a chart cannot disagree about what "Fitness"
    // looks like. Hues are spread around the wheel far enough apart to stay distinguishable.
    public static func ramp(for domain: SkillDomain) -> ColorRamp {
        switch domain {
        case .fitness:    ColorRamp(hue: 352, baseSaturation: 0.76, base: 0.60)
        case .intellect:  ColorRamp(hue: 224, baseSaturation: 0.80, base: 0.62)
        case .creativity: ColorRamp(hue: 284, baseSaturation: 0.72, base: 0.64)
        case .discipline: ColorRamp(hue: 152, baseSaturation: 0.64, base: 0.50)
        case .social:     ColorRamp(hue: 28,  baseSaturation: 0.86, base: 0.58)
        case .wealth:     ColorRamp(hue: 188, baseSaturation: 0.70, base: 0.52)
        }
    }

    /// The shade of a domain colour to use for text or an icon on a dark surface.
    ///
    /// Not the base shade: at 60% lightness a saturated hue is a fine button fill but thin as
    /// text. *"Accessible doesn't have to mean ugly"* (p164) — the way out is to move along the
    /// ramp rather than toward white, keeping the colour recognisable.
    public static func onSurface(_ domain: SkillDomain) -> HSL { ramp(for: domain)[300] }

    /// The shade to fill a solid button or badge with, chosen by measurement.
    ///
    /// A fixed shade cannot work for every hue, and finding that out is what this method is for.
    /// White on `accent[500]` measured 4.25:1 and `health[500]` 3.66:1 -- both under the 4.5:1
    /// AA floor, exactly as Refactoring UI warns on p163. Dropping to shade 700 fixed those two,
    /// and then gold still failed at 4.13:1 with *either* foreground: at that lightness it is
    /// too bright to carry white text and too dark to carry black, a dead zone created by
    /// yellow's high perceived brightness (p154).
    ///
    /// So the shade is searched instead of assumed. Dark fills are preferred because they suit
    /// a dark interface; bright fills with dark text -- the contrast flip from p164 -- are the
    /// fallback that rescues hues like gold.
    public static func buttonFill(_ ramp: ColorRamp) -> HSL {
        // Brightest-first among the shades that suit a dark interface. 700 passes AA but reads
        // dull and heavy as a call to action; 600 is a step brighter and, as the contrast sweep
        // confirms, still clears 4.5:1. Bright fills with dark text -- the flip from p164 -- come
        // last, as the fallback that rescues high-brightness hues like gold.
        let preference = [600, 700, 500, 800, 400, 300, 200, 100]
        for shade in preference {
            let candidate = ramp[shade]
            if candidate.contrastRatio(against: foreground(on: candidate)) >= 4.5 {
                return candidate
            }
        }
        return ramp[900]
    }

    /// The text colour to put on a filled surface: whichever of the two reads better.
    ///
    /// Chosen by measurement rather than by eye, so a new accent colour cannot quietly ship
    /// with unreadable text on top of it.
    public static func foreground(on fill: HSL) -> HSL {
        fill.contrastRatio(against: textOnAccent) >= fill.contrastRatio(against: textOnBright)
            ? textOnAccent
            : textOnBright
    }

    /// A very dark tint of a colour, for a panel that should read as belonging to that colour
    /// without shouting. The "flipped contrast" option from p164.
    public static func tintedSurface(_ ramp: ColorRamp) -> HSL {
        let base = ramp[500]
        return HSL(base.hue, base.saturation * 0.42, 0.145)
    }

    /// All text/background pairs that must satisfy WCAG, with the size class each is used at.
    ///
    /// Enumerated here rather than in the test so that adding a colour to the palette and
    /// forgetting to check it is a visible omission in this file.
    public static var contrastPairs: [(name: String, foreground: HSL, background: HSL, isLargeText: Bool)] {
        var pairs: [(String, HSL, HSL, Bool)] = []
        let backgrounds: [(String, HSL)] = [
            ("canvas", canvas), ("surface", surface),
            ("surfaceRaised", surfaceRaised), ("surfaceHighest", surfaceHighest),
        ]
        for (bgName, bg) in backgrounds {
            pairs.append(("textPrimary on \(bgName)", textPrimary, bg, false))
            pairs.append(("textSecondary on \(bgName)", textSecondary, bg, false))
            // Tertiary is only ever used for large or supporting type, so it is held to 3:1.
            pairs.append(("textTertiary on \(bgName)", textTertiary, bg, true))
            for domain in SkillDomain.allCases {
                pairs.append(("\(domain.rawValue) on \(bgName)", onSurface(domain), bg, true))
            }
            pairs.append(("accent on \(bgName)", accent[300], bg, true))
            pairs.append(("health on \(bgName)", health[300], bg, true))
            pairs.append(("gold on \(bgName)", gold[300], bg, true))
            pairs.append(("success on \(bgName)", success[300], bg, true))
        }
        // Solid button fills, with near-white text on top.
        for (name, ramp) in [("accent", accent), ("health", health), ("success", success), ("gold", gold)] {
            let fill = buttonFill(ramp)
            pairs.append(("auto-foreground on \(name) button", foreground(on: fill), fill, false))
        }
        // Flipped-contrast panels: coloured text on a dark tint of the same hue.
        for (name, ramp) in [("accent", accent), ("health", health), ("gold", gold), ("success", success)] {
            pairs.append(("\(name)300 on \(name) tint", ramp[300], tintedSurface(ramp), true))
            pairs.append(("textPrimary on \(name) tint", textPrimary, tintedSurface(ramp), false))
        }
        return pairs
    }
}
