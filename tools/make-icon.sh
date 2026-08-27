#!/usr/bin/env bash
#
# Regenerates the app icon from the app's own palette.
#
# The icon is source, not an asset someone dropped in: `Sources/ascend-icon` draws it from
# `Palette`, so if the accent hue changes the icon changes with it. Run this after touching
# either, and commit the PNGs it writes.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Ascend/Assets.xcassets/AppIcon.appiconset
swift run --package-path Packages/AscendCore ascend-icon "$OUT"

# App Store validation rejects a primary iOS icon carrying an alpha channel, and the failure
# arrives at upload time rather than at build time. Check it here instead.
for f in icon-light icon-dark; do
  if [ "$(sips -g hasAlpha "$OUT/$f.png" | tail -1 | awk '{print $2}')" != "no" ]; then
    echo "FAIL $f.png has an alpha channel; iOS will reject it" >&2
    exit 1
  fi
done
echo "ok   no alpha on the primary icons"
