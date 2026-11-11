#!/usr/bin/env python3
"""Check the translation files against the L["..."] keys used by the addon.

Usage: python3 tools/check_locales.py [--keys]

- Lists keys a locale file is missing (untranslated, falls back to English)
  and keys it has that the addon no longer uses (stale).
- Fails (exit 1) when a translation's format placeholders (%s, %d, %.1f ...)
  differ from the English key, because string.format would then break.
- --keys prints every key used by the addon, one per line, for translators.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KEY_RE = re.compile(r'\bL\["((?:[^"\\]|\\.)*)"\]')
ENTRY_RE = re.compile(r'^\s*\["((?:[^"\\]|\\.)*)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*,?\s*$')
LOCALE_RE = re.compile(r'(?:TB|TortoiseBots)\.RegisterLocale\(\s*"(\w+)"')
FORMAT_RE = re.compile(r'%[-+ #0]*\d*(?:\.\d+)?[sdifgxXc%]')


def addon_files():
    toc = (ROOT / "TortoiseBotsManager.toc").read_text(encoding="utf-8")
    for line in toc.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            yield ROOT / line.replace("\\", "/")


def used_keys():
    keys = {}
    for path in addon_files():
        if path.parts[-2] == "Locales":
            continue
        text = path.read_text(encoding="utf-8")
        for m in KEY_RE.finditer(text):
            keys.setdefault(m.group(1), path.name)
    return keys


def locale_files():
    for path in sorted((ROOT / "Locales").glob("*.lua")):
        text = path.read_text(encoding="utf-8")
        m = LOCALE_RE.search(text)
        if not m:
            continue
        entries = {}
        for line in text.splitlines():
            e = ENTRY_RE.match(line)
            if e:
                entries[e.group(1)] = e.group(2)
        yield m.group(1), path, entries


def placeholders(text):
    return [p for p in FORMAT_RE.findall(text) if p != "%%"]


def main():
    keys = used_keys()
    if "--keys" in sys.argv:
        for key in sorted(keys):
            print(key)
        return 0
    failed = False
    print(f"{len(keys)} keys used by the addon")
    for locale, path, entries in locale_files():
        missing = sorted(k for k in keys if not entries.get(k))
        stale = sorted(k for k in entries if k not in keys)
        bad = sorted(k for k, v in entries.items() if v and placeholders(k) != placeholders(v))
        print(f"{locale} ({path.name}): {len(keys) - len(missing)}/{len(keys)} translated, "
              f"{len(missing)} missing, {len(stale)} stale, {len(bad)} placeholder mismatches")
        for k in missing:
            print(f"  missing: {k}")
        for k in stale:
            print(f"  stale:   {k}")
        for k in bad:
            print(f"  PLACEHOLDER MISMATCH: {k!r} -> {entries[k]!r}")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
