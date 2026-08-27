# Engineering notes

Things that went wrong, and what they cost to find. Recorded because most of them look like a
different problem than they are.

## The compiler is silent on the most dangerous mistake here

`@Model` **attaches `Sendable`.** Check it yourself:

```sh
grep -n "public macro Model" \
  "$(xcrun --sdk iphoneos --show-sdk-path)"/System/Library/Frameworks/SwiftData.framework/Modules/SwiftData.swiftmodule/*.swiftinterface
```

It compiles because the macro rewrites every persisted `var` into a computed property over
`_$backingData`, leaving no mutable stored state for the concurrency checker to object to. So
`Task.detached { print(task.title) }` compiles clean and then reads torn state or trips CoreData's
thread assertions at runtime.

There is no compiler help available. It is a review rule instead: **a `@Model` instance never
leaves the main actor**; cross-isolation handoff uses `PersistentIdentifier` — which is genuinely
`Sendable` — plus a re-fetch via `context.model(for:)`. `ModelContext` itself is safe by
comparison: its `Sendable` conformance is marked `@available(*, unavailable)`, so passing a context
across a boundary is a real compile error with a real message.

## Three type names shadow something SwiftUI needs, and none says so

| Name | Symptom |
|---|---|
| `Task` | every `Task { await … }` in the module becomes a compile error |
| `Section` | shadows `SwiftUI.Section`, breaking `List` content |
| `Tab` | *"requires that Tab conform to TabContent"* — reads as a protocol problem |

All three happened in this repo. The task model is `QuestTask`; the grouping view is
`LabeledGroup`; the tab enum is `RootTab`.

## `id` collided with `PersistentIdentifier`, and the compiler crashed rather than explain

Every model originally declared `var id: UUID`. But `PersistentModel` already conforms to
`Identifiable` and supplies `var id: PersistentIdentifier`, so each type had **two** `id` members
and the `Identifiable` associated type became ambiguous.

The error was not a name conflict. `ForEach(milestones)` failed to type-check and the compiler
reported *"failed to produce diagnostic for expression; please submit a bug report"*. Finding it
took bisecting the view down to a stub. The property is now `uuid`, and the two identities —
SwiftUI's and the ledger's durable reference — are distinctly named.

## An actor-isolation mismatch, also reported as a compiler crash

```swift
ErrorCard(onRetry: error.isRetryable ? generate : nil)   // "failed to produce diagnostic"
```

Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, a method reference has type
`@MainActor () -> Void`, which will not convert to a bare `() -> Void`. Swift declined to say so.
SwiftUI callbacks in the app target are now typed `(@MainActor () -> Void)?`.

## A deploy script that installed a stale build and reported success

The first device-install step checked `test -d "$APP"` before installing. When the build failed,
the *previous* `.app` was still on disk, so the check passed and the phone silently received old
code — reported as a success.

`tools/deploy-device.sh` now gates the install on xcodebuild's **exit status**, never on a file's
existence. Verified by deliberately breaking a source file: exit 1, nothing installed. Deleting the
old bundle first is belt-and-braces only — Xcode recreates the `.app` directory before it fails
compiling, so its existence proves nothing either way.

## A check in `check.sh` that was passing vacuously

The script verifies that the test count quoted in the README matches the count the suite actually
ran. The extraction used `sed` with `\b`, which **BSD sed does not support** — so it matched
nothing and the comparison never happened. Exactly the failure mode the script exists to prevent.

Fixed with `grep -oE`, and then proven by setting the README to a wrong number and confirming the
check fails. Every architecture guard has since been negative-tested the same way.

## Escalation charged maximum damage on a brand-new task

Miss damage escalates with consecutive missed days. The walk backwards through the ledger had no
lower bound, so a task that had *never* been completed had no completion on any earlier day
either — the walk ran to the escalation ceiling and charged the maximum the first time a new step
was missed. Neglect can only be counted from the day the thing started existing.

## `gameDayKey(for:)` normalises its argument, and that has bitten twice

`gameDay(for:)` shifts an instant back by `dayStartHour` and takes the start of day. Feeding a
value that already came out of it normalises twice and lands a day early.

Both times it presented as an off-by-one in a loop rather than as double-normalisation: once a
streak came out one short, once a drift check reported 60 days for a goal completed that morning.
`key(ofGameDayStart:)` is now public and named for the precondition it requires.

## `.rateLimited` was absorbed by `@unknown default`

`LanguageModelSession.GenerationError.rateLimited` is a **declared** case. The translation switch
did not handle it, so it fell into `@unknown default` and surfaced as "Planning stopped
unexpectedly" — telling the user nothing and hiding a condition that clears on its own.

Found while chasing a single generation failure during a ~70-call eval run, which is easily enough
to trip it. Now its own retryable error. Worth noting that `@unknown default` is what made this
invisible; it silences the exhaustiveness warning that would have caught it.

## A prompt example leaked into unrelated output

The `@Guide` description for a step title used a concrete example: *"Write 16 bars of lyrics"*. A
**SwiftUI** roadmap came back containing *"Write 16 bars of lyrics to showcase improved user
interface."*

Every example is now pattern-based — a digit plus a unit drawn from the goal's own subject
matter — with an explicit instruction never to borrow units from another domain.

## Measurements that were noisier than the thing being measured

At the model's default sampling temperature, the same goal scored 52/100 and then 95/100 on
consecutive runs. Any single-run before/after comparison was therefore meaningless, and the first
improvement figure quoted from one was not sound.

Temperature dropped to 0.35 and `ascend-eval` gained `--runs N`. The reported 53 → 81 is a mean
over 12 runs. A per-goal spread is printed alongside it, because one goal still swings 36 points
and hiding that behind an average would be dishonest.

## A breaking schema change with no migration, on purpose

Renaming `id` to `uuid` changed the store's shape. Opening a pre-rename store with the new schema
logs several hundred `com.apple.coredata:error` entries while it fails to reconcile the missing
column; a virgin store is clean, verified by erasing a simulator and counting zero on both first
and second launch.

`AscendSchemaV1` is at 1.1.0 with no `SchemaMigrationPlan`, and that is deliberate: the app has
never shipped, so the only affected stores are development installs, and a migration plan for a
schema no user has would be dead code pretending to be diligence. The next schema change does need
one — and that version identifier is what it will migrate from.
