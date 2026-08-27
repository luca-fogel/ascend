import SwiftUI
import AscendDomain

/// The SwiftUI face of the design system.
///
/// The values themselves live in `AscendDomain/Design` as plain data, because that is what
/// makes them testable — `PaletteContrastTests` sweeps every text-on-surface pairing against
/// WCAG AA, and it found two real failures the moment it was written. This file only converts
/// them into SwiftUI types and packages them as modifiers.
///
/// Everything here traces to a rule in *Refactoring UI* (Wathan & Schoger); the reasoning is
/// recorded next to the values it produced rather than summarised here.
enum Theme {

    // MARK: - Colour

    enum Colors {
        static let background = Color(Palette.canvas)
        static let surface = Color(Palette.surface)
        static let surfaceRaised = Color(Palette.surfaceRaised)
        static let surfaceHighest = Color(Palette.surfaceHighest)
        static let topHighlight = Color(Palette.topHighlight)
        static let hairline = Color(Palette.hairline)

        static let primaryText = Color(Palette.textPrimary)
        static let secondaryText = Color(Palette.textSecondary)
        static let tertiaryText = Color(Palette.textTertiary)

        static let accent = Color(Palette.accent[300])
        static let accentFill = Color(Palette.buttonFill(Palette.accent))
        static let hp = Color(Palette.health[300])
        static let gold = Color(Palette.gold[300])
        static let success = Color(Palette.success[300])

        /// Text that sits on a filled surface, measured rather than assumed.
        static func onFill(_ ramp: ColorRamp) -> Color {
            Color(Palette.foreground(on: Palette.buttonFill(ramp)))
        }

        /// A dark tint of a hue, for a panel that should belong to a colour without shouting.
        /// The "flip the contrast" option (p164).
        static func tint(_ ramp: ColorRamp) -> Color { Color(Palette.tintedSurface(ramp)) }
    }

    // MARK: - Type
    //
    // Six sizes and two weights. The old scale had nine sizes with 15/16/17 all in service of
    // the same job — the exact symptom "Establish a type scale" (p102) opens with. Weights
    // under regular are gone: de-emphasis is colour's job, not weight's (p41).

    enum Fonts {
        static let display = style(TypeSize.display, .semibold)
        static let title = style(TypeSize.title, .semibold)
        static let headline = style(TypeSize.headline, .semibold)
        static let body = style(TypeSize.body, .regular)
        static let bodyEmphasis = style(TypeSize.body, .semibold)
        static let caption = style(TypeSize.caption, .regular)
        static let captionEmphasis = style(TypeSize.caption, .semibold)
        static let micro = style(TypeSize.micro, .semibold)

        static func style(_ size: Double, _ weight: TypeWeight) -> Font {
            .system(size: size,
                    weight: weight == .semibold ? .semibold : .regular,
                    design: .rounded)
        }

        /// Monospaced digits, so a counting-up number does not jitter its neighbours.
        static func number(_ size: Double, _ weight: TypeWeight = .semibold) -> Font {
            .system(size: size,
                    weight: weight == .semibold ? .semibold : .regular,
                    design: .rounded).monospacedDigit()
        }
    }

    /// The spacing scale. Values at the top end are more generous than they were —
    /// "Start with too much white space" (p66) — and every adjacent pair is now at least a 25%
    /// step apart, which the previous 20→24 pairing was not (p72).
    enum Spacing {
        static let xs = Space.xxs      // 4
        static let sm = Space.xs       // 8
        static let md = Space.sm       // 12
        static let base = Space.md     // 16
        static let lg = Space.lg       // 24
        static let xl = Space.xl       // 32
        static let xxl = Space.xxl     // 48
    }

    enum Radii {
        static let sm = Radius.sm
        static let md = Radius.md
        static let lg = Radius.lg
        static let xl = Radius.xl
    }

    enum Motion {
        static let standard = Animation.spring(response: 0.38, dampingFraction: 0.78)
        static let quick = Animation.spring(response: 0.24, dampingFraction: 0.82)
        static let celebratory = Animation.spring(response: 0.5, dampingFraction: 0.6)
        static let stagger: Double = 0.06
    }
}

extension Color {
    /// Bridges a domain `HSL` into SwiftUI.
    ///
    /// Goes through `.rgb` rather than `Color(hue:saturation:brightness:)` on purpose: SwiftUI's
    /// initialiser is HS**B**, and using it where HSL is meant washes out every light shade
    /// (Refactoring UI p141).
    init(_ hsl: HSL) {
        let (r, g, b) = hsl.rgb
        self.init(.sRGB, red: r, green: g, blue: b, opacity: hsl.alpha)
    }
}

// MARK: - Text

extension View {
    /// Applies a font together with its line spacing and tracking.
    ///
    /// They travel as a unit because they are not independent: line spacing is inversely
    /// proportional to size (p122), and all-caps text needs opening up while large display type
    /// wants tightening (p132). Setting the font without the other two is how those rules get
    /// quietly dropped.
    func textStyle(_ size: Double, _ weight: TypeWeight = .regular, allCaps: Bool = false) -> some View {
        self
            .font(Theme.Fonts.style(size, weight))
            .lineSpacing(LineSpacing.forSize(size))
            .tracking(allCaps ? Tracking.allCaps
                              : (size >= TypeSize.title ? Tracking.display : Tracking.none))
    }
}

// MARK: - Depth

extension View {
    /// A two-part shadow at a given elevation.
    ///
    /// "Shadows can have two parts" (p186): a large soft shadow for the light the object blocks,
    /// and a tight dark one for the ambient light that cannot reach beneath it. One shadow
    /// cannot do both jobs — and per p188 the tight one fades as elevation rises, vanishing
    /// entirely at the top.
    /// - Parameter tint: an optional ramp whose colour the shadow borrows. Filipiuk p117: a
    ///   coloured shadow under a coloured element makes it pop in a way a neutral one cannot.
    func elevation(_ level: Elevation, tint: ColorRamp? = nil) -> some View {
        // Never `.black`. Filipiuk p116: pure black reads unnatural, because nothing in the real
        // world casts one. This is the dark end of the grey ramp, so shadows share the
        // interface's cool temperature.
        let base = tint.map { Color(Palette.shadow(for: $0)) } ?? Color(Palette.shadow)
        return self
            .shadow(color: base.opacity(level.cast.opacity),
                    radius: level.cast.radius, x: 0, y: level.cast.yOffset)
            .shadow(color: base.opacity(level.contact?.opacity ?? 0),
                    radius: level.contact?.radius ?? 0, x: 0, y: level.contact?.yOffset ?? 0)
    }

    /// Guarantees a finger-sized hit area without changing what is drawn.
    ///
    /// Filipiuk p128: text links and icon buttons need a tappable region larger than their
    /// glyph, at least 44x44pt on mobile. `contentShape` is the part that matters -- without it
    /// the frame is bigger but only the drawn pixels respond.
    func tapTarget(_ size: Double = TapTarget.minimum) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(.rect)
    }

    /// The standard panel.
    ///
    /// Three changes from the version this replaces, each from a specific rule:
    ///
    /// - **No border.** "Use fewer borders" (p238) — every card previously carried a hairline
    ///   stroke, which on a dark interface is pure noise when the surface is already lighter
    ///   than its background and casting a shadow. Separation is doing its job twice.
    /// - **A lighter top edge.** "Emulate a light source" (p172) — light comes from above, so
    ///   the upward-facing edge catches it. This is what makes a panel read as raised rather
    ///   than merely as a different colour. Hand-picked, not translucent white, which drains
    ///   the saturation from what is underneath (p176).
    /// - **A two-part shadow** at an explicit elevation, rather than one arbitrary blur.
    func card(_ elevationLevel: Elevation = .medium,
              padding: Double = Theme.Spacing.lg,
              accent: Color? = nil,
              surface: Color = Theme.Colors.surface) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(surface)
            .overlay(alignment: .top) {
                // The lit edge. A gradient rather than a flat line so it fades away from the
                // top rather than ringing the whole panel.
                LinearGradient(colors: [Theme.Colors.topHighlight.opacity(0.9), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1)
            }
            .overlay(alignment: .top) {
                // "Add color with accent borders" (p224): a colourful bar across the top of a
                // card is the cheapest way to make something feel designed.
                if let accent {
                    Rectangle().fill(accent).frame(height: 3)
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radii.lg))
            .elevation(elevationLevel)
    }
}

// MARK: - Grouping

/// A titled group of rows.
///
/// Named `LabeledGroup` rather than `Section` so it cannot shadow `SwiftUI.Section`, which the
/// settings screen uses inside a `List`.
///
/// Exists to enforce "Avoid ambiguous spacing" (p96): whenever spacing is what connects a group,
/// there must be more space *around* the group than *within* it. Previously the gap between the
/// section header and its first row was the same 12pt as the gap between rows, so nothing read
/// as belonging to anything.
struct LabeledGroup<Content: View>: View {
    let title: String
    var trailing: AnyView?
    @ViewBuilder var content: () -> Content

    init(_ title: String, trailing: AnyView? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .textStyle(TypeSize.micro, .semibold, allCaps: true)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .textCase(.uppercase)
                Spacer()
                if let trailing { trailing }
            }
            VStack(spacing: Theme.Spacing.sm) { content() }
        }
    }
}

/// Press feedback for any button.
///
/// Filipiuk p129 lists four button states -- default, hover, pressed, disabled -- and notes that
/// designers routinely ship only the first. There is no hover on iOS, but pressed was missing
/// everywhere, which means every tap in the app was silent until its side effect appeared.
///
/// The shadow shrinks as the element scales down, which is p184's advice in Refactoring UI too:
/// a button that loses its elevation reads as being pushed into the surface.
struct PressableButtonStyle: ButtonStyle {
    var scale: Double = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: Timing.feedback), value: configuration.isPressed)
    }
}

/// A tertiary action.
///
/// "Semantics are secondary" (p60): tertiary actions should be discoverable but unobtrusive, so
/// they are styled like links. And "Not every link needs a color" (p126) — in an interface where
/// almost everything is tappable, painting every one accent-blue is overbear, so these use a
/// secondary text colour with weight doing the work instead.
struct TertiaryButton: View {
    let title: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(TypeSize.caption, .semibold)
                // A text link is a few points tall; the tappable area must not be.
                .padding(.vertical, Theme.Spacing.md)
                .padding(.horizontal, Theme.Spacing.xs)
                .tapTarget()
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .foregroundStyle(Theme.Colors.secondaryText)
    }
}

/// A primary action.
struct PrimaryButton: View {
    let title: String
    var ramp: ColorRamp = Palette.accent
    var isEnabled: Bool = true
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(TypeSize.body, .semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .foregroundStyle(Theme.Colors.onFill(ramp))
                .background(Color(Palette.buttonFill(ramp)))
                .clipShape(.rect(cornerRadius: Theme.Radii.md))
                // A disabled button gets no shadow: Filipiuk p117 -- shadows signal
                // interactivity, so putting one on something inert is a false promise.
                .elevation(isEnabled ? .low : .flat, tint: isEnabled ? ramp : nil)
                // Comfortably inside the 40-60pt range recommended on p122.
                .frame(minHeight: TapTarget.minimum)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// A secondary action: clear, but not competing with the primary one (p61).
struct SecondaryButton: View {
    let title: String
    let action: @MainActor () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(TypeSize.body, .semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .foregroundStyle(Theme.Colors.primaryText)
                .background(Theme.Colors.surfaceHighest)
                .clipShape(.rect(cornerRadius: Theme.Radii.md))
                .frame(minHeight: TapTarget.minimum)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// An icon in a tinted container.
///
/// "Everything has an intended size" (p208): an icon drawn for 16–24pt looks chunky and
/// under-detailed blown up to 40pt for an empty state. The book's fix is to keep the glyph near
/// its intended size and enclose it in a shape that fills the space instead.
struct IconBadge: View {
    let systemName: String
    var tint: Color = Theme.Colors.accent
    var size: Double = 56

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.3))
    }
}
