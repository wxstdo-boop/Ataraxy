#!/usr/bin/env python3
"""Regenerate TODOS.md from in-code markers.

Collects every `NOTE:` / `TODO:` / `FIXME` comment in lib/ so the tracked
follow-ups in TODOS.md never drift from the source. Run from the repo root:

    python3 tools/build_todos.py
"""

from pathlib import Path

MARKERS = ("NOTE:", "TODO:", "FIXME")
ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"


def main() -> None:
    rows: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        for lineno, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if any(marker in line for marker in MARKERS):
                rel = path.relative_to(ROOT).as_posix()
                rows.append(f"* {rel}:{lineno} - {line.strip()}")

    out = ["# Project TODOs", ""]
    out.extend(rows)
    out.append("")
    out.append(f"Total: {len(rows)} items")
    out.append("")
    (ROOT / "TODOS.md").write_text("\n".join(out), encoding="utf-8")
    print(f"Wrote TODOS.md ({len(rows)} items)")


if __name__ == "__main__":
    main()
