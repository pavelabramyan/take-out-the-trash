#!/bin/bash
# Двойной клик в Finder — запуск вне Cursor (иначе процесс гасится).
cd "$(dirname "$0")"
exec ./tools/launch_mac.sh
