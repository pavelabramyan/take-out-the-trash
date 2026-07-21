#!/usr/bin/env bash
# Стабильный запуск на Mac AMD: OpenGL + open -n (вне дерева процессов Cursor).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/Godot.app"
if [[ ! -d "$APP" ]]; then
  echo "Нет Godot.app в корне проекта" >&2
  exit 1
fi
# Убить старый запуск этой игры
pkill -f "Godot.app/Contents/MacOS/Godot --path ${ROOT}" 2>/dev/null || true
sleep 0.5
open -n "$APP" --args \
  --path "$ROOT" \
  --windowed \
  --resolution 1280x720 \
  --position 80,60 \
  --rendering-method gl_compatibility \
  --rendering-driver opengl3 \
  "$@"
sleep 1
osascript -e 'tell application "System Events" to set frontmost of first process whose name contains "Godot" to true' 2>/dev/null || true
echo "Запущено (ищи окно Godot / ВЫНЕСИ МУСОР!)"
