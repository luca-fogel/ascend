import Testing
import Foundation
@testable import AscendDomain

@Suite("Palette: HSL maths")
struct HSLTests {

    @Test("HSL converts to the RGB values it should, including the greys")
    func conversionIsCorrect() {
        // Spot values with known answers, so a broken conversion cannot hide behind
        // colours that merely look plausible.
        func approx(_ a: Double, _ b: Double, _ tol: Double = 0.002) -> Bool { abs(a - b) < tol }

        let red = HSL(0, 1, 0.5).rgb
        #expect(approx(red.red, 1) && approx(red.green, 0) && approx(red.blue, 0))

        let white = HSL(0, 0, 1).rgb
        #expect(approx(white.red, 1) && approx(white.green, 1) && approx(white.blue, 1))

        let black = HSL(0, 0, 0).rgb
        #expect(approx(black.red, 0) && approx(black.green, 0) && approx(black.blue, 0))

        // Saturation 0 at any hue is the same grey -- the property the book notes on p139.
        let greyA = HSL(0, 0, 0.5).rgb
        let greyB = HSL(275, 0, 0.5).rgb
        #expect(approx(greyA.red, greyB.red) && approx(greyA.green, greyB.green))

        let teal = HSL(180, 1, 0.5).rgb
        #expect(approx(teal.red, 0) && approx(teal.green, 1) && approx(teal.blue, 1))
    }

    @Test("this is HSL, not HSB -- full lightness is white at any saturation")
    func isNotHSB() {
        // The distinction the book flags on p141. In HSB, brightness 1 with saturation 1 is a
        // vivid hue; in HSL, lightness 1 is white regardless. Getting this wrong silently
        // washes out every light shade in the palette.
        let hslLightest = HSL(224, 1, 1).rgb
        #expect(hslLightest.red == 1 && hslLightest.green == 1 && hslLightest.blue == 1)
        // And lightness 0.5 at full saturation is the pure hue, not white.
        let pure = HSL(224, 1, 0.5).rgb
        #expect(pure.blue > 0.9 && pure.red < 0.4)
    }

    @Test("contrast ratio matches the WCAG reference values")
    func contrastRatioIsCorrect() {
        let white = HSL(0, 0, 1)
        let black = HSL(0, 0, 0)
        // Black on white is the maximum, 21:1.
        #expect(abs(white.contrastRatio(against: black) - 21) < 0.01)
        // A colour against itself is 1:1.
        #expect(abs(white.contrastRatio(against: white) - 1) < 0.001)
        // Symmetric.
        #expect(white.contrastRatio(against: black) == black.contrastRatio(against: white))
        // #767676 on white is the canonical 4.54:1 boundary case.
        let mid = HSL(0, 0, 0.4627)
        #expect(abs(white.contrastRatio(against: mid) - 4.54) < 0.06)
    }

    @Test("hue rotation moves toward the target and stays bounded")
    func hueRotation() {
        let blue = HSL(224, 0.8, 0.6)
        let rotated = blue.rotatingHue(toward: 180, by: 0.5)
        // 224 -> 180 is -44 degrees, half of that is -22.
        #expect(abs(rotated.hue - 202) < 0.5)
        #expect(rotated.saturation == blue.saturation)
        #expect(rotated.lightness == blue.lightness)
    }

    @Test("the nearest bright hue is one of the three perceptual maxima")
    func nearestBrightHue() {
        #expect(HSL(224, 1, 0.5).nearestBrightHue == 180)
        #expect(HSL(30, 1, 0.5).nearestBrightHue == 60)
        #expect(HSL(310, 1, 0.5).nearestBrightHue == 300)
    }
}

@Suite("Palette: ramps")
struct ColorRampTests {

    @Test("a ramp has nine shades that get monotonically darker from 100 to 900")
    func rampIsMonotonic() {
        for ramp in [Palette.accent, Palette.gold, Palette.health, Palette.success, Palette.grey] {
            #expect(ramp.shades.count == 9)
            let ordered = [100, 200, 300, 400, 500, 600, 700, 800, 900].map { ramp[$0] }
            for index in 1..<ordered.count {
                #expect(ordered[index].lightness < ordered[index - 1].lightness,
                        "shade \(index * 100 + 100) was not darker than the one before it")
            }
        }
    }

    @Test("saturation rises as lightness leaves the middle, so the ends don't wash out")
    func saturationLiftsAtTheEdges() {
        // Refactoring UI p152. Holding saturation flat makes the lightest and darkest shades
        // look chalky and muddy respectively.
        let ramp = Palette.accent
        #expect(ramp[100].saturation > ramp[500].saturation)
        #expect(ramp[900].saturation > ramp[500].saturation)
    }

    @Test("light shades rotate toward a brighter hue, but never far enough to change colour")
    func hueRotationIsBoundedTo24Degrees() {
        for ramp in [Palette.accent, Palette.gold, Palette.health, Palette.success] {
            let base = ramp[500].hue
            for shade in [100, 200, 300, 400] {
                let drift = abs(ramp[shade].hue - base)
                #expect(drift <= 24.5, "shade \(shade) drifted \(drift) degrees from the base hue")
            }
        }
    }

    @Test("every skill domain has a visually distinct hue")
    func domainHuesAreDistinct() {
        // Colour is load-bearing for reading a character as a shape, so two domains that look
        // alike would undermine the whole skill-tree idea.
        let hues = SkillDomain.allCases.map { Palette.ramp(for: $0)[500].hue }
        for i in hues.indices {
            for j in hues.indices where j > i {
                let raw = abs(hues[i] - hues[j])
                let separation = min(raw, 360 - raw)
                #expect(separation >= 30, "two domain hues were only \(separation) degrees apart")
            }
        }
    }
}

@Suite("Palette: accessibility")
struct PaletteContrastTests {

    /// WCAG 2.1 AA, quoted in Refactoring UI p162: 4.5:1 for normal text, 3:1 for large text.
    @Test("every text-on-surface pairing in the palette meets WCAG AA")
    func allPairsMeetAA() {
        var failures: [String] = []
        for pair in Palette.contrastPairs {
            let required = pair.isLargeText ? 3.0 : 4.5
            let ratio = pair.foreground.contrastRatio(against: pair.background)
            if ratio < required {
                failures.append("\(pair.name) = \(ratio):1 (needs \(required):1)")
            }
        }
        let report = failures.joined(separator: "; ")
        #expect(failures.isEmpty, "\(report)")
    }

    @Test("primary text clears AAA, not just AA -- it is most of the words in the app")
    func primaryTextIsAAA() {
        for background in [Palette.canvas, Palette.surface, Palette.surfaceRaised, Palette.surfaceHighest] {
            let ratio = Palette.textPrimary.contrastRatio(against: background)
            #expect(ratio >= 7, "primary text was only \(ratio):1")
        }
    }

    @Test("the three text shades are clearly separated, not three names for the same grey")
    func textShadesAreDistinguishable() {
        // "Size isn't everything" (p38) only works if the three levels actually differ.
        let primary = Palette.textPrimary.contrastRatio(against: Palette.surface)
        let secondary = Palette.textSecondary.contrastRatio(against: Palette.surface)
        let tertiary = Palette.textTertiary.contrastRatio(against: Palette.surface)
        #expect(primary > secondary * 1.4)
        #expect(secondary > tertiary * 1.4)
    }

    @Test("every surface is lighter than the one it sits on, so depth reads without shadows")
    func surfacesAscend() {
        // "Even flat designs can have depth" (p190): lighter is closer.
        #expect(Palette.canvas.lightness < Palette.surface.lightness)
        #expect(Palette.surface.lightness < Palette.surfaceRaised.lightness)
        #expect(Palette.surfaceRaised.lightness < Palette.surfaceHighest.lightness)
        // And the top highlight is lighter still than the highest surface, because it is the
        // edge catching the light from above.
        #expect(Palette.surfaceHighest.lightness < Palette.topHighlight.lightness)
    }

    @Test("greys are saturated, not true grey")
    func greysAreNotGrey() {
        // "Greys don't have to be grey" (p158).
        #expect(Palette.canvas.saturation > 0.1)
        #expect(Palette.surface.saturation > 0.1)
        #expect(Palette.textSecondary.saturation > 0.05)
    }
}

@Suite("Palette: scales")
struct DesignScaleTests {

    @Test("no two adjacent spacing values are closer than 25%")
    func spacingScaleHasUsefulGaps() {
        // The rule that makes a spacing system worth having (p72). The previous scale had a 20%
        // step from 20 to 24, which is the sort of gap you waste time choosing between.
        for index in 1..<Space.all.count {
            let ratio = Space.all[index] / Space.all[index - 1]
            #expect(ratio >= 1.25,
                    "\(Space.all[index - 1]) -> \(Space.all[index]) is only a \(Int((ratio - 1) * 100))% step")
        }
    }

    @Test("the type scale has no indistinguishable neighbours")
    func typeScaleIsDistinguishable() {
        // Six sizes, down from nine: 15/16/17 previously all existed for the same job.
        for index in 1..<TypeSize.all.count {
            let ratio = TypeSize.all[index] / TypeSize.all[index - 1]
            #expect(ratio >= 1.14,
                    "\(TypeSize.all[index - 1])pt -> \(TypeSize.all[index])pt is too small a jump")
        }
    }

    @Test("line spacing falls as type size rises")
    func lineSpacingIsInverselyProportional() {
        // "Line-height is proportional" (p122).
        #expect(LineSpacing.forSize(TypeSize.caption) > LineSpacing.forSize(TypeSize.title))
        #expect(LineSpacing.forSize(TypeSize.display) == 0)
    }

    @Test("the contact shadow fades as elevation rises, and is gone at the top")
    func elevationContactShadowFades() {
        // "Shadows can have two parts" (p188): the tight ambient shadow disappears as an object
        // moves away from the surface.
        let contacts = [Elevation.low, .medium, .high].map { $0.contact!.opacity }
        for index in 1..<contacts.count {
            #expect(contacts[index] < contacts[index - 1])
        }
        #expect(Elevation.highest.contact == nil)
    }

    @Test("cast shadows grow with elevation")
    func elevationCastShadowGrows() {
        let radii = Elevation.all.map(\.cast.radius)
        for index in 1..<radii.count {
            #expect(radii[index] > radii[index - 1])
        }
    }
}

@Suite("Palette: foreground selection")
struct ForegroundSelectionTests {

    @Test("the foreground picked for a fill is always the higher-contrast of the two")
    func picksTheBetterForeground() {
        for ramp in [Palette.accent, Palette.gold, Palette.health, Palette.success] {
            for shade in [300, 500, 700] {
                let fill = ramp[shade]
                let chosen = Palette.foreground(on: fill)
                let other = chosen == Palette.textOnAccent ? Palette.textOnBright : Palette.textOnAccent
                #expect(fill.contrastRatio(against: chosen) >= fill.contrastRatio(against: other))
            }
        }
    }

    @Test("gold gets dark text and accent gets light text")
    func goldFlipsTheContrast() {
        // The concrete case that forced this helper to exist.
        #expect(Palette.foreground(on: Palette.buttonFill(Palette.gold)) == Palette.textOnBright)
        #expect(Palette.foreground(on: Palette.buttonFill(Palette.accent)) == Palette.textOnAccent)
    }
}
