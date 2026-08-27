# The design system

Every token in `AscendDomain/Design` traces to a rule in one of two books. This is the index; the
reasoning lives in doc comments at the point of use, next to the values it produced.

- *Refactoring UI* — Adam Wathan & Steve Schoger (cited **RUI**)
- *UI Design Principles* — Michael Filipiuk (cited **UIDP**)

Neither book is included in this repository.

## Why the palette is in the domain layer

Colours are plain `HSL` values in `AscendDomain`, not `Color` literals in view files, for one
reason: **it makes them testable.** RUI p162 gives hard numbers — 4.5:1 contrast for normal text,
3:1 for large — so `PaletteContrastTests` sweeps every text-on-surface pairing in
`Palette.contrastPairs`.

It failed the day it was written:

| Pairing | Measured | Required |
|---|---|---|
| White on `accent[500]` | 4.25:1 | 4.5:1 |
| White on `health[500]` | 3.66:1 | 4.5:1 |
| Either foreground on `gold[700]` | 4.13:1 | 4.5:1 |

The first two were fixed by darkening the fill. Gold could not be: at that lightness it is too
bright to carry white text and too dark to carry black — a dead zone created by yellow's high
perceived brightness (RUI p154). RUI p164's answer is to flip the contrast rather than fight it, so
`Palette.buttonFill` **searches** the ramp for a shade whose best-measured foreground clears AA,
preferring dark fills and falling back to bright fills with dark text.

A consequence worth stating: a new accent colour cannot ship with unreadable text on it. Add a
colour, add it to `contrastPairs`.

## Colour

| Token | Rule |
|---|---|
| `HSL`, hand-written conversion | RUI p138 "Ditch hex for HSL". Deliberately **HSL, not HSB** (p141) — SwiftUI only offers HSB, and using it where HSL is meant washes out every light shade. |
| Nine-shade `ColorRamp` | RUI p142 "You need more colors than you think", p148 "Define your shades up front". |
| Saturation rises toward both ends | RUI p152 — in HSL the effect of saturation weakens toward black and white, so a flat value makes both ends look washed out. |
| Light shades rotate ≤24° toward the nearest bright hue | RUI p155. Beyond ~30° it reads as a different colour rather than a lighter one. |
| Greys saturated to 220° | RUI p158 "Greys don't have to be grey". Also UIDP p101, which derives the greyscale from the primary hue at S=20, L=10 — the same idea. |
| Three text shades, hand-picked | RUI p42. These were `Color.white.opacity(0.62)` and similar; reducing opacity lowers contrast but drains saturation and lets the background show through, so text reads dull and faintly disabled. |
| Distinct warning and error hues | UIDP p98. Every error rendered gold, so an ineligible device carried the same weight as a goal needing three more words. `AscendError.severity` now drives it. |
| Shadows are never `#000000` | UIDP p116 — nothing in the real world casts a pure black shadow. |
| Coloured shadows under coloured elements | UIDP p117, applied only to filled buttons. |

## Layout and type

| Token | Rule |
|---|---|
| Spacing scale, every step ≥25% | RUI p72. The previous scale had a 20→24 step — a 20% gap, exactly the kind you waste time choosing between. Asserted by test. |
| Generous top end | RUI p66 "Start with too much white space". |
| Six type sizes, hand-crafted | RUI p102. The old scale had nine, with 15/16/17 all serving the same job — the symptom the chapter opens with. |
| Two weights, nothing under regular | RUI p41. De-emphasis is colour's job, not weight's. |
| Line spacing falls as size rises | RUI p122 "Line-height is proportional". |
| Tracking opened on all-caps, tightened on display | RUI p132. |
| `LabeledGroup` spacing | RUI p96 "Avoid ambiguous spacing" — more space around a group than within it. The section header and its first row were previously the same 12pt apart as the rows. |
| Baseline alignment for mixed sizes | RUI p118 "Baseline, not center". |
| Long paragraphs left-aligned | RUI p128. |
| Consistent radius throughout | RUI p24, UIDP p23. Mixing square and rounded is worse than either. |

## Depth

Five elevations, each a **two-part shadow**: a large soft cast shadow for the light the object
blocks, and a tight dark contact shadow for the ambient light that cannot reach beneath it
(RUI p186). One shadow cannot do both jobs. Per p188 the contact shadow fades as elevation rises
and is absent at the top — asserted by test.

Panels carry a lighter top edge, because light comes from above (RUI p172). Hand-picked rather
than a translucent white, which drains the saturation from whatever is underneath (p176).

Panels carry **no border**. RUI p238: every card previously had a hairline stroke while also being
a lighter surface *and* casting a shadow — separation doing its job three times. Text inputs are
the exception, and keep theirs (UIDP p140): a filled rectangle with no border reads as a button,
which is a confusing thing to put in a form.

## Interaction

| Token | Rule |
|---|---|
| `TapTarget.minimum = 44` | UIDP p128, p148. The completion circle on every task row was 28×28. |
| `PressableButtonStyle` | UIDP p129 lists four button states and notes that only the first usually ships. Pressed was missing everywhere, so every tap was silent until its side effect appeared. |
| Disabled buttons are flat | UIDP p117 — a shadow signals interactivity, so putting one on something inert is a false promise. |
| Primary action on the right | UIDP p134 — ~90% of people are right-handed, so the right side is the easier thumb reach. Three button pairs were the wrong way round. |
| `LabelledField` keeps its label | UIDP p138. Both forms were placeholder-only, and a placeholder disappears the moment you type. |
| Focus state on inputs | UIDP p155 — there was none, so tapping a field confirmed nothing. |
| "(optional)", not asterisks | UIDP p160. |
| `Timing`, all under 1s | UIDP p286 — an animation held for effect is an animation in the way. |
| Haptics scaled to the event | UIDP p282. On a phone, the fastest acknowledgement is not visual. |
| Specific button text | UIDP p246. "Add it" → "Add the side-quest"; "Face it" → "Start fighting Procrastination". |
| Icons in containers for hero slots | RUI p208 — an icon drawn for 16–24pt reads chunky blown up to 40pt. |
| Icons softened next to text | RUI p56 "Balance weight and contrast" — a solid glyph covers more surface area than the text beside it. |

## Where the books disagree

UIDP p117 says shadows belong only on **interactive** elements. RUI uses them freely to convey
elevation on any panel. This codebase keeps elevation for grouping — it is load-bearing for the
figure-ground reading of a dark interface — but makes disabled controls flat. A judgement call, not
a rule followed.

## Rules deliberately not applied

Photography, text-on-images and user-uploaded content (no images in the app); line length,
hyphenation and justified text (no long-form prose); 12-column web grids and `em` units (not
concepts in SwiftUI); favicons; font-directory selection (using SF, which both books' advice
points at); dropdowns, radio buttons, sliders, sidebars, hidden navigation and desktop text tabs
(none exist here). The tab bar was already compliant with UIDP p261 — five tabs, labels on all of
them, which the book requires be all-or-nothing.
