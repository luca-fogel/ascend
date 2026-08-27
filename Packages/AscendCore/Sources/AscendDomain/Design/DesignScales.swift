import Foundation

/// The spacing scale.
///
/// *"Establish a spacing and sizing system"* (Refactoring UI, p70) with the rule that makes it
/// actually useful: **no two adjacent values closer than about 25%.** The previous scale broke
/// that — 20 to 24 is a 20% step, which is exactly the kind of gap that leaves you dithering
/// between two values that look identical. This one steps 100/50/33/50/33/50/33%.
public enum Space {
    public static let xxs: Double = 4
    public static let xs: Double = 8
    public static let sm: Double = 12
    public static let md: Double = 16
    public static let lg: Double = 24
    public static let xl: Double = 32
    public static let xxl: Double = 48
    public static let xxxl: Double = 64

    public static let all: [Double] = [xxs, xs, sm, md, lg, xl, xxl, xxxl]
}

/// The type scale.
///
/// *"Establish a type scale"* (p102), hand-crafted rather than modular — a ratio produces
/// fractional sizes and the wrong density at the bottom of the scale.
///
/// Six sizes, down from nine. The old scale had 15, 16 and 17 all in use for near-identical
/// jobs, which is the exact symptom the chapter opens with: "every pixel value from 10 to 24
/// has been used in the UI somewhere". Sizes that cannot be told apart are not a scale.
public enum TypeSize {
    /// All-caps section labels only.
    public static let micro: Double = 12
    public static let caption: Double = 14
    public static let body: Double = 16
    public static let headline: Double = 20
    public static let title: Double = 24
    public static let display: Double = 34

    public static let all: [Double] = [micro, caption, body, headline, title, display]
}

/// *"Size isn't everything"* (p38): two weights are enough for UI work, and nothing under
/// regular. Lighter weights were being used to de-emphasise text, which the book says to do
/// with colour or size instead — so they are gone.
public enum TypeWeight: Sendable {
    /// Most text.
    case regular
    /// Emphasis, and numerals.
    case semibold
}

/// *"Line-height is proportional"* (p122): line spacing and font size are inversely related.
/// Small text needs the extra room to help the eye find the next line; a 34pt display line
/// needs none.
public enum LineSpacing {
    public static func forSize(_ size: Double) -> Double {
        switch size {
        case ..<13:  4
        case ..<17:  5
        case ..<21:  4
        case ..<25:  2
        default:     0
        }
    }
}

/// *"Use letter-spacing effectively"* (p132).
public enum Tracking {
    /// All-caps text has no ascenders or descenders to tell letters apart, so it needs opening
    /// up. This is the single most visible letter-spacing win in the app: every section header
    /// is uppercase.
    public static let allCaps: Double = 0.8
    /// Large display type gets tightened slightly, mimicking a purpose-built headline face.
    public static let display: Double = -0.6
    public static let none: Double = 0
}

/// *"Use shadows to convey elevation"* (p180) and *"Shadows can have two parts"* (p186).
///
/// Five levels. Each is two shadows, because one cannot do both jobs: a large soft shadow for
/// the light the object blocks, and a tight dark one for the ambient light that cannot reach
/// underneath it. Per p188 the tight shadow fades as elevation rises — distinct at rest,
/// nearly gone when something is floating above the UI.
public struct Elevation: Sendable, Equatable {
    public struct Shadow: Sendable, Equatable {
        public let opacity: Double
        public let radius: Double
        public let yOffset: Double
        public init(opacity: Double, radius: Double, yOffset: Double) {
            self.opacity = opacity
            self.radius = radius
            self.yOffset = yOffset
        }
    }

    /// The larger, softer cast shadow.
    public let cast: Shadow
    /// The tighter, darker ambient-occlusion shadow. `nil` at the highest elevation.
    public let contact: Shadow?

    public init(cast: Shadow, contact: Shadow?) {
        self.cast = cast
        self.contact = contact
    }

    /// Flush with the background. No shadow at all.
    public static let flat = Elevation(cast: Shadow(opacity: 0, radius: 0, yOffset: 0), contact: nil)
    /// A button, or a row that should read as slightly lifted.
    public static let low = Elevation(cast: Shadow(opacity: 0.22, radius: 3, yOffset: 1),
                                      contact: Shadow(opacity: 0.34, radius: 1, yOffset: 1))
    /// The default card.
    public static let medium = Elevation(cast: Shadow(opacity: 0.26, radius: 10, yOffset: 4),
                                         contact: Shadow(opacity: 0.22, radius: 2, yOffset: 1))
    /// A sheet or a popover.
    public static let high = Elevation(cast: Shadow(opacity: 0.32, radius: 22, yOffset: 10),
                                       contact: Shadow(opacity: 0.12, radius: 3, yOffset: 1))
    /// A modal, where attention should be captured outright.
    public static let highest = Elevation(cast: Shadow(opacity: 0.40, radius: 40, yOffset: 20),
                                          contact: nil)

    public static let all: [Elevation] = [low, medium, high, highest]
}

/// Minimum sizes for things a finger has to hit.
///
/// *UI Design Principles* (Filipiuk, p128 and p148) puts a number on it: **44x44pt**, matching
/// Apple's own HIG. It applies to icon buttons, text links, checkboxes and radio buttons -- all
/// the elements small enough that it is tempting to size them to their glyph. The tappable area
/// can extend beyond the visible mark; it just has to exist.
public enum TapTarget {
    public static let minimum: Double = 44
}

/// Microinteraction timings.
///
/// Filipiuk p286: a microinteraction exists to give feedback for an action the user took, and it
/// must stay *micro* -- nothing over 1000ms, because people use apps faster than that and an
/// animation held for effect is an animation in the way.
public enum Timing {
    /// A press, a toggle, a checkbox filling in.
    public static let feedback: Double = 0.12
    /// A value changing, a bar growing.
    public static let transition: Double = 0.30
    /// A level-up or a boss falling. The upper bound of "micro".
    public static let celebration: Double = 0.55
}

/// *"Choose a personality"* (p20): a consistent, small radius throughout. Ascend should read as
/// a precise instrument rather than a toy, so nothing is fully rounded except pills and rings —
/// and mixing square with rounded, which the book warns against, does not happen anywhere.
public enum Radius {
    public static let sm: Double = 10
    public static let md: Double = 14
    public static let lg: Double = 20
    public static let xl: Double = 28
}
