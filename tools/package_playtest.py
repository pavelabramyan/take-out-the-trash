#!/usr/bin/env python3
"""Упаковка playtest-zip."""
from __future__ import annotations
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WIN = ROOT / "build" / "win"
OUT = ROOT / "build" / "TakeOutTheTrash_Windows_Playtest.zip"


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if not WIN.exists():
        print("WARN: build/win missing — skip zip")
        return
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for p in WIN.rglob("*"):
            if p.is_file():
                z.write(p, p.relative_to(WIN))
    print("PACKED", OUT)


if __name__ == "__main__":
    main()
