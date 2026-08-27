#!/usr/bin/env bash
#
# Everything CI runs, runnable on a laptop.
#
# The checks live here rather than in a workflow file so they can be run without GitHub -- a
# check that cannot run on a stock machine is a check that quietly stops being run.
set -euo pipefail
cd "$(dirname "$0")/.."

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
fail() { echo "${RED}FAIL${OFF} $1"; exit 1; }
ok()   { echo "${GREEN}ok${OFF}   $1"; }

# ---------------------------------------------------------------------------
# 1. The engine suite. No simulator, no Apple Intelligence, ~0.4s.
# ---------------------------------------------------------------------------
echo "${DIM}-- swift test (AscendCore)${OFF}"
TEST_LOG=$(mktemp)
if ! swift test --package-path Packages/AscendCore > "$TEST_LOG" 2>&1; then
  cat "$TEST_LOG"; fail "swift test"
fi
COUNT=$(grep -oE "Test run with [0-9]+ test" "$TEST_LOG" | grep -oE "[0-9]+" | tail -1)
[ -n "$COUNT" ] || { cat "$TEST_LOG"; fail "could not read the test count"; }
ok "swift test -- $COUNT tests"

# The README quotes the test count; a stale number is a small lie that erodes the rest.
if grep -q "tests" README.md; then
  README_COUNT=$(grep -oE '[0-9]+ tests' README.md | grep -oE '[0-9]+' | head -1)
  if [ -n "$README_COUNT" ] && [ "$README_COUNT" != "$COUNT" ]; then
    fail "README says $README_COUNT tests, the suite ran $COUNT"
  fi
  ok "README test count matches"
fi

# ---------------------------------------------------------------------------
# 2. Architecture guards.
#
# These are the two promises this project makes that a reader cannot verify by reading, so
# they are enforced mechanically instead of documented and hoped for.
# ---------------------------------------------------------------------------
echo "${DIM}-- architecture guards${OFF}"
CORE=Packages/AscendCore/Sources

# (a) No networking and no credentials, anywhere. "Apple Intelligence only, no API keys" stops
#     being a claim in a README and becomes a build failure.
FORBIDDEN='URLSession|URLRequest|api\.anthropic|x-api-key|ANTHROPIC_API_KEY|SecItemAdd|CFStreamCreatePair'
# Comment lines are stripped before matching: several files *document* the fact that they must
# never use URLSession, and a guard that trips on its own explanation is a guard that gets
# deleted. `grep -n` emits `path:line:text`, so dropping matches whose text begins with // or *
# is enough.
NET_HITS=$(grep -rInE "$FORBIDDEN" "$CORE" Ascend --include='*.swift' \
            | grep -vE ':[0-9]+:[[:space:]]*(///?|\*)' || true)
if [ -n "$NET_HITS" ]; then
  echo "$NET_HITS"
  fail "networking or credential handling found -- Ascend is on-device only"
fi
ok "no networking, no credentials"

# (b) The engine cannot import the view layer. This is what makes "the game engine is
#     decoupled from the views" a fact rather than an intention.
if grep -rInE '^[[:space:]]*import (SwiftUI|UIKit|AppKit)' "$CORE" --include='*.swift'; then
  fail "AscendCore imported a UI framework"
fi
ok "AscendCore imports no UI framework"

# (c) Layer boundaries inside the package. AscendDomain is pure; AscendIntelligence must not
#     reach into the store -- it emits DTOs and RoadmapImporter does the writing.
if grep -rInE '^[[:space:]]*import (SwiftData|FoundationModels)' "$CORE/AscendDomain" --include='*.swift'; then
  fail "AscendDomain must stay Foundation-only"
fi
ok "AscendDomain is Foundation-only"

if grep -rInE '^[[:space:]]*import (SwiftData|AscendPersistence)' "$CORE/AscendIntelligence" --include='*.swift'; then
  fail "AscendIntelligence must not depend on persistence"
fi
ok "AscendIntelligence does not touch the store"

# (d) FoundationModels stays in one layer, so availability gating has exactly one home.
if grep -rIn '^[[:space:]]*import FoundationModels' Ascend --include='*.swift'; then
  fail "the app target imported FoundationModels directly"
fi
ok "FoundationModels confined to AscendIntelligence"

# (e) `Task` must not be reintroduced as a model name -- it shadows _Concurrency.Task
#     module-wide and turns every `Task { await ... }` into a compile error.
# Anchored to a real declaration at the start of a line, so the doc comment in
# QuestTask.swift that *explains* this rule does not trip it.
if grep -rInE '^[[:space:]]*(public |internal |private |fileprivate )?(final )?class Task[[:space:]]*[:{]' \
     "$CORE" Ascend --include='*.swift'; then
  fail "a class named Task would shadow _Concurrency.Task module-wide"
fi
ok "no @Model shadows _Concurrency.Task"

# ---------------------------------------------------------------------------
# 3. The app target compiles against the real SDK.
#
# Skipped when there is no Xcode, so the script still runs somewhere minimal.
# ---------------------------------------------------------------------------
if command -v xcodebuild >/dev/null 2>&1 && [ "${SKIP_XCODEBUILD:-0}" != "1" ]; then
  echo "${DIM}-- xcodebuild (iPhone 17 Pro)${OFF}"
  command -v xcodegen >/dev/null 2>&1 && xcodegen generate --quiet
  BUILD_LOG=$(mktemp)
  if ! xcodebuild -project Ascend.xcodeproj -scheme Ascend \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -quiet build > "$BUILD_LOG" 2>&1; then
    cat "$BUILD_LOG"; fail "xcodebuild"
  fi
  ok "app target builds for the simulator"
else
  echo "${DIM}skip${OFF} xcodebuild (no Xcode, or SKIP_XCODEBUILD=1)"
fi

echo
echo "${GREEN}All checks passed.${OFF}"
