#!/usr/bin/env bash
# Запуск на Mac: Forward+/Vulkan в окне. `--gl` — аварийный откат на OpenGL.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/Godot.app"
if [[ ! -d "$APP" ]]; then
  echo "Нет Godot.app в корне проекта" >&2
  exit 1
fi

METHOD="forward_plus"
DRIVER="vulkan"
if [[ "${1:-}" == "--gl" ]]; then
  METHOD="gl_compatibility"
  DRIVER="opengl3"
  shift
  echo "Откат на OpenGL Compatibility"
fi

# Убить старый запуск этой игры
pkill -f "Godot.app/Contents/MacOS/Godot --path ${ROOT}" 2>/dev/null || true
sleep 0.5
# Fullscreen на Retina валит MoltenVK/AMD — всегда окно
open -n "$APP" --args \
  --path "$ROOT" \
  --windowed \
  --resolution 1280x720 \
  --position 80,60 \
  --rendering-method "$METHOD" \
  --rendering-driver "$DRIVER" \
  "$@"
sleep 1
osascript -e 'tell application "System Events" to set frontmost of first process whose name contains "Godot" to true' 2>/dev/null || true
echo "Запущено (${METHOD}/${DRIVER}) — ищи окно ВЫНЕСИ МУСОР!"
