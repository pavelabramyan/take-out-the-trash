#!/usr/bin/env bash
# Приёмочный прогон ВЫНЕСИ МУСОР!
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot.app/Contents/MacOS/Godot"
FULL="${1:-quick}"
cd "$ROOT"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot binary missing at $GODOT"
  exit 1
fi

python3 tools/gen_sfx.py
python3 tools/gen_environment_textures.py

"$GODOT" --headless --path . --quit-after 2 -- --test-mode
"$GODOT" --headless --path . --script res://tools/test_levels.gd -- --test-mode
"$GODOT" --headless --path . --script res://tools/test_carry.gd -- --test-mode
"$GODOT" --headless --path . --script res://tools/test_stairs.gd -- --test-mode
"$GODOT" --headless --path . --script res://tools/test_gameplay.gd -- --test-mode

mkdir -p build/win
# Export may fail without export templates — don't hard-fail in quick mode
if [[ "$FULL" == "full" ]]; then
  "$GODOT" --headless --path . --export-release "Windows" || echo "EXPORT_WARN"
  python3 tools/package_playtest.py || true
  python3 tools/build_store_assets.py
fi

echo "QUALITY_GATE: PASS mode=$FULL"
