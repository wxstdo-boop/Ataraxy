#!/usr/bin/env python3
"""Regenerate lib/l10n/strings_data.g.dart from the ARB files.

The ARB files under lib/l10n/arb/ are the single source of truth for every
user-facing string. This script flattens them into the const maps that the
`L` helper reads at runtime, so `L.tr` / `L.trStatic` keep their string-key
API while the data itself lives in ARB.

Run from the repository root:

    python3 tools/build_l10n.py
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ARB_DIR = ROOT / "lib" / "l10n" / "arb"
OUT = ROOT / "lib" / "l10n" / "strings_data.g.dart"
LANGS = ["ru", "en", "fr"]


def dart_string(value: str) -> str:
    out = []
    for ch in value:
        if ch == "\\":
            out.append("\\\\")
        elif ch == "'":
            out.append("\\'")
        elif ch == "$":
            out.append("\\$")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        else:
            out.append(ch)
    return "'" + "".join(out) + "'"


def load(lang: str) -> dict:
    data = json.loads((ARB_DIR / f"app_{lang}.arb").read_text(encoding="utf-8"))
    return {k: v for k, v in data.items() if not k.startswith("@")}


def main() -> None:
    by_lang = {lang: load(lang) for lang in LANGS}

    keys = list(by_lang["ru"].keys())
    for lang in LANGS[1:]:
        assert list(by_lang[lang].keys()) == keys, f"key set differs for {lang}"

    lines = [
        "// GENERATED CODE - DO NOT MODIFY BY HAND.",
        "//",
        "// Produced by tools/build_l10n.py from lib/l10n/arb/*.arb.",
        "// Regenerate after editing any ARB file: python3 tools/build_l10n.py",
        "",
        "/// UI strings, keyed by message id and then by language code.",
        "const Map<String, Map<String, String>> kStrings = {",
    ]
    sign_keys = [k for k in keys if k.startswith("sign_")]
    for key in keys:
        if key.startswith("sign_"):
            continue
        entries = ", ".join(
            f"{dart_string(lang)}: {dart_string(by_lang[lang][key])}"
            for lang in LANGS
        )
        lines.append(f"  {dart_string(key)}: {{{entries}}},")
    lines.append("};")
    lines.append("")
    lines.append("/// Dream-sign labels, keyed by sign id and then by language code.")
    lines.append("const Map<String, Map<String, String>> kSignLabels = {")
    for key in sign_keys:
        entries = ", ".join(
            f"{dart_string(lang)}: {dart_string(by_lang[lang][key])}"
            for lang in LANGS
        )
        lines.append(f"  {dart_string(key[len('sign_'):])}: {{{entries}}},")
    lines.append("};")
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)} ({len(keys)} messages)")


if __name__ == "__main__":
    main()
