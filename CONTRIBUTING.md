# Contributing

This is a personal project, but `Packages/AscendCore` — the game engine, the progression
maths, and the on-device planning layer — is the part that is generally useful, the part most
likely to have a bug you have hit too, and the part you can work on without Xcode. Those are
the contributions I most want.

## Start here

```sh
swift test --package-path Packages/AscendCore   # ~0.5s, no Xcode, no simulator, no Apple Intelligence
tools/check.sh                                  # what CI runs
xcodegen generate && open Ascend.xcodeproj      # then ⌘R
```

For a screenshot or a look at one screen without walking the UI, debug builds take
`-tab today|goals|bosses|character|settings` and `-sheet goal|habit`.

If you have a Mac with Apple Intelligence enabled, `swift run --package-path
Packages/AscendCore ascend-eval` runs the real on-device planner and scores its output. Pass
`--runs 3` before believing any result — see the note on variance below.

## The rules this code lives by

- **The engine never imports SwiftUI.** `AscendCore` may use Foundation, SwiftData and
  FoundationModels; the app target holds no game arithmetic and makes no model calls.
  `tools/check.sh` fails if that stops being true, and the three layers enforce it further:
  `AscendDomain` is Foundation-only, and `AscendIntelligence` cannot see the store at all — it
  emits plain DTOs and a `RoadmapImporter` on the persistence side does the writing.
- **Nothing leaves the device.** There is no account, no server, no API key, and no networking
  code anywhere. `check.sh` fails on `URLSession`, `URLRequest`, or a credential literal. If you
  are adding a feature that needs the network, that is a conversation before it is a pull
  request.
- **A balance number lives in `GameRules`, not in the engine.** `GameManager` owns no
  constants. Changing how the game feels should be a diff to one value type plus a diff to the
  test that pins it — never a hunt through the engine.
- **The engine returns a description of what happened.** `complete()` hands back a
  `CompletionOutcome` and the view animates from it. No view recomputes XP, and no view knows
  the progression curve. Keep it that way: it is why the whole ruleset is testable headlessly.
- **A design token is data, not a colour literal in a view.** The palette lives in
  `AscendDomain/Design` precisely so `PaletteContrastTests` can sweep every text-on-surface
  pairing against WCAG AA. It found two real failures the day it was written. If you add a
  colour, add it to `Palette.contrastPairs` too.
- **Undo subtracts a fact.** `CompletionLog` records the amounts actually applied — clamped, not
  nominal — because a streak-multiplied award cannot be recomputed once the streak has moved.
  If you add a reward, record what was granted.

## Things that will bite you

- **Never name a type `Task`, `Section`, or `Tab`.** All three shadow something SwiftUI or the
  concurrency library needs, and none of them fails with a message that says so. `Task` turns
  every `Task { await … }` into a compile error; `Tab` reports *"requires that Tab conform to
  TabContent"*. This has happened three times in this repo. The task model is `QuestTask`.
- **`@Model` attaches `Sendable`.** The compiler will *not* stop a model crossing an isolation
  boundary. It is a review rule instead: a `@Model` instance never leaves the main actor, and
  cross-isolation handoff uses `PersistentIdentifier` plus a re-fetch.
- **`StreakCalculator.gameDayKey(for:)` normalises its argument.** Passing it a value that came
  out of `gameDay(for:)` normalises twice and lands a day early. Use `key(ofGameDayStart:)` for
  those. Two separate call sites have made this mistake and both presented as an off-by-one.
- **On-device output varies run to run.** During prompt tuning one goal scored 52/100 and then
  95/100 on consecutive runs — a spread wider than most of the changes being tested. Use
  `ascend-eval --runs N` and compare means, or you will chase noise.

## Commits

Lower-case imperative subject, no prefix convention, and sign off with `git commit -s`
(Developer Certificate of Origin).

## Credit where it is due

The design system was built by working through two books, and the reasoning is cited at the
point of use with page numbers rather than summarised anywhere:

- *Refactoring UI* — Adam Wathan & Steve Schoger
- *UI Design Principles* — Michael Filipiuk

Neither book is included here. If a comment cites a page and you want the argument behind it,
they are both worth owning.
