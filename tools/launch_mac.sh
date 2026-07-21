#!/usr/bin/env bash
# Стабильный запуск на Mac AMD: OpenGL Compatibility вместо Vulkan/MoltenVK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${ROOT}/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$GODOT" ]]; then
  echo "Нет Godot.app в корне проекта" >&2
  exit 1
fi
exec "$GODOT" --path "$ROOT" --windowed --resolution 1280x720 --position 80,60 \
  --rendering-method gl_compatibility --rendering-driver opengl3 "$@"
