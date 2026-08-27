import Testing
import Foundation
@testable import AscendDomain

/// Rules from *UI Design Principles* (Michael Filipiuk) that can be checked rather than trusted.
@Suite("Notification colours")
struct SeverityTests {

    @Test("warnings and errors are separated, not all rendered the same")
    func severitySplitsTheCases() {
        // p98 names three notification colours -- green success, orange warning, red error. Every
        // error in this app used to render gold, so an ineligible device carried the same visual
        // weight as a goal that needed three more words.
        #expect(AscendError.goalTooVague.severity == .warning)
        #expect(AscendError.generationBusy.severity == .warning)
        #expect(AscendError.generationRateLimited.severity == .warning)
        #expect(AscendError.appleIntelligenceModelNotReady.severity == .warning)

        #expect(AscendError.appleIntelligenceUnsupportedDevice.severity == .error)
        #expect(AscendError.goalRefused.severity == .error)
        #expect(AscendError.invalidRoadmap("x").severity == .error)
        #expect(AscendError.noProfile.severity == .error)
    }

    @Test("a condition that clears on its own is never styled as a hard failure")
    func retryableThingsAreWarnings() {
        // If waiting or retrying fixes it, it is not an error -- and if it is an error, no amount
        // of retrying should be implied.
        for error in [AscendError.generationBusy, .generationRateLimited,
                      .appleIntelligenceModelNotReady] {
            #expect(error.severity == .warning)
            #expect(error.isRetryable)
        }
        #expect(AscendError.appleIntelligenceUnsupportedDevice.severity == .error)
        #expect(!AscendError.appleIntelligenceUnsupportedDevice.isRetryable)
    }
}

@Suite("Tap targets and timing")
struct InteractionTests {

    @Test("the minimum tap target is 44pt, matching the HIG")
    func tapTargetFloor() {
        // p128 and p148. The completion circle in a task row was 28x28 before this.
        #expect(TapTarget.minimum == 44)
    }

    @Test("every microinteraction stays under a second")
    func microinteractionsStayMicro() {
        // p286: an animation held for effect is an animation in the way.
        for duration in [Timing.feedback, Timing.transition, Timing.celebration] {
            #expect(duration < 1.0, "\(duration)s is no longer micro")
            #expect(duration > 0)
        }
        // And they are ordered by the weight of the event they acknowledge.
        #expect(Timing.feedback < Timing.transition)
        #expect(Timing.transition < Timing.celebration)
    }
}

@Suite("Shadow colour")
struct ShadowTests {

    @Test("shadows are never pure black")
    func shadowsAreTinted() {
        // p116: #000000 reads unnatural because nothing in the real world casts a pure black
        // shadow. Every shadow in the app used `.black` before this.
        #expect(Palette.shadow.saturation > 0.2)
        #expect(Palette.shadow.lightness > 0)
        let (r, g, b) = Palette.shadow.rgb
        #expect(!(r == 0 && g == 0 && b == 0))
    }

    @Test("a tinted shadow keeps its element's hue and stays dark")
    func tintedShadowsFollowTheirElement() {
        // p117: a coloured shadow under a coloured element makes it pop. It still has to be a
        // shadow, though -- dark enough to read as one.
        for ramp in [Palette.accent, Palette.health, Palette.gold, Palette.success] {
            let shadow = Palette.shadow(for: ramp)
            let hueGap = abs(shadow.hue - ramp[600].hue)
            #expect(min(hueGap, 360 - hueGap) < 1)
            #expect(shadow.lightness <= 0.12)
            #expect(shadow.saturation > 0.3)
        }
    }
}

@Suite("Input borders")
struct InputTests {

    @Test("an input's border is visible against its own fill, so it reads as a field")
    func inputBorderIsVisible() {
        // p140: a filled rectangle with no border reads as a button, which is a confusing thing
        // to put in a form. Panels lost their borders; inputs kept theirs.
        let contrast = Palette.inputBorder.contrastRatio(against: Palette.surfaceRaised)
        #expect(contrast > 1.25, "border was only \(contrast):1 against the field fill")
    }

    @Test("focus visibly changes the border, so a tap is acknowledged")
    func focusIsVisible() {
        // p155: every form element needs its states designed. There was no focus state at all.
        let resting = Palette.inputBorder
        let focused = Palette.inputBorderFocused
        #expect(focused.contrastRatio(against: Palette.surfaceRaised)
                > resting.contrastRatio(against: Palette.surfaceRaised) * 1.5)
        #expect(focused.saturation > resting.saturation)
    }
}
