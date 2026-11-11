#!/usr/bin/env python3
"""Developer helper: wrap plain English string literals in display calls with L["..."].

Usage: python3 tools/wrap_strings.py [--write] FILE.lua [FILE.lua ...]

Only these call shapes are touched, and only when the argument is one plain
string literal (no concatenation), so commands and protocol text stay as is:
  :SetText("..."), GameTooltip:AddLine/SetText("..."), TB.SetStatus("..."),
  TB.Print("..."), TB.UI.CreateButton/CreateTogglePill(parent, "..."),
  setButtonTooltip(btn, "...", "..."), and table fields tip/tipTitle/label/
  text = "...".
Literals with colour codes (|c) or without two letters in a row are left
alone and listed, as are concatenated display strings, for manual review.
Without --write it only reports.
"""
import pathlib
import re
import sys

LIT = r'"((?:[^"\\\n]|\\.)*)"'
PATTERNS = [
    re.compile(r'(:SetText\(\s*)' + LIT + r'(?=\s*[,)])'),
    re.compile(r'(GameTooltip:(?:AddLine|SetText)\(\s*)' + LIT + r'(?=\s*[,)])'),
    re.compile(r'(TB\.SetStatus\(\s*)' + LIT + r'(?=\s*[,)])'),
    re.compile(r'(TB\.Print\(\s*)' + LIT + r'(?=\s*[,)])'),
    re.compile(r'(TB\.UI\.Create(?:Button|TogglePill)\(\s*[\w.]+\s*,\s*)' + LIT + r'(?=\s*,)'),
    re.compile(r'(setButtonTooltip\(\s*[\w.]+\s*,\s*)' + LIT + r'(?=\s*[,)])'),
    re.compile(r'(setButtonTooltip\(\s*[\w.]+\s*,\s*L\["(?:[^"\\]|\\.)*"\]\s*,\s*)' + LIT + r'(?=\s*\))'),
    re.compile(r'(\b(?:tip|tipTitle|label|text)\s*=\s*)' + LIT + r'(?=\s*[,}\n])'),
]
# Local display helpers: helper name -> 0-based positions of display-text arguments.
HELPERS = {
    "setTooltip": [1, 2],
    "smallButton": [1, 5, 6],
    "orderButton": [1, 4, 5],
    "makeTab": [1],
    # local button helpers differ per file; chosen by argument count
    "button": {3: [0, 2], 5: [0, 4], 7: [1, 6]},
    "card": [0],
    "note": [1],
    "line": [2],
    "stepper": [2, 4],
    "searchBox": [4],
    "tabButton": [0],
    "setFeedback": [0],
}


def split_args(text, start):
    """Split call arguments beginning at text[start] (just after '('). Returns list of (s, e) spans and end index."""
    depth, i, spans, arg_start, in_str = 0, start, [], start, None
    while i < len(text):
        ch = text[i]
        if in_str:
            if ch == "\\":
                i += 2
                continue
            if ch == in_str:
                in_str = None
        elif ch in "\"'":
            in_str = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            if depth == 0:
                spans.append((arg_start, i))
                return spans, i
            depth -= 1
        elif ch == "," and depth == 0:
            spans.append((arg_start, i))
            arg_start = i + 1
        i += 1
    return spans, i


def wrap_helpers(src, report):
    count = 0
    out, pos = [], 0
    for m in re.finditer(r'(?<![\w.:])(' + "|".join(HELPERS) + r')\(', src):
        name = m.group(1)
        line_start = src.rfind("\n", 0, m.start()) + 1
        prefix = src[line_start:m.start()]
        if re.search(r'\bfunction\s*$', prefix) or prefix.lstrip().startswith("--"):
            continue
        spans, _ = split_args(src, m.end())
        positions = HELPERS[name]
        if isinstance(positions, dict):
            positions = positions.get(len(spans), [])
        for idx in positions:
            if idx >= len(spans):
                continue
            s, e = spans[idx]
            arg = src[s:e]
            lit = re.fullmatch(r'(\s*)' + LIT + r'(\s*)', arg, re.S)
            if lit and s >= pos:
                if wants(lit.group(2)):
                    out.append(src[pos:s])
                    out.append(lit.group(1) + 'L["' + lit.group(2) + '"]' + lit.group(3))
                    pos = e
                    count += 1
            elif arg.strip().startswith("{") and s >= pos:
                body = re.sub(LIT, lambda mm: ('L["' + mm.group(1) + '"]') if wants(mm.group(1)) else mm.group(0), arg)
                if body != arg:
                    count += len(re.findall(r'L\["', body)) - len(re.findall(r'L\["', arg))
                    out.append(src[pos:s])
                    out.append(body)
                    pos = e
    out.append(src[pos:])
    return "".join(out), count


CONCAT = re.compile(r'(?::SetText|AddLine|SetStatus|TB\.Print)\(\s*"[^"\n]*[A-Za-z]{2}[^"\n]*"\s*\.\.'
                    r'|(?::SetText|AddLine|SetStatus|TB\.Print)\([^)\n]*\.\.\s*"[^"\n]*[A-Za-z]{2}[^"\n]*"')


def wants(text):
    return re.search(r'[A-Za-z]{2}', text) and '|c' not in text and '|T' not in text


def process(path, write):
    raw = path.read_bytes()
    crlf = b"\r\n" in raw
    src = raw.decode("utf-8").replace("\r\n", "\n")
    out_lines, wrapped, skipped, concat = [], 0, [], []
    for no, line in enumerate(src.split("\n"), 1):
        if line.lstrip().startswith("--"):
            out_lines.append(line)
            continue
        for pat in PATTERNS:
            def sub(m):
                nonlocal wrapped
                if not wants(m.group(2)):
                    if re.search(r'[A-Za-z]{3}', m.group(2)):
                        skipped.append((no, m.group(2)))
                    return m.group(0)
                wrapped += 1
                return m.group(1) + 'L["' + m.group(2) + '"]'
            line = pat.sub(sub, line)
        if CONCAT.search(line):
            concat.append((no, line.strip()))
        out_lines.append(line)
    out = "\n".join(out_lines)
    out, helper_count = wrap_helpers(out, None)
    wrapped += helper_count
    if wrapped and "local L = TB.L" not in out:
        out, n = re.subn(r'^(local TB\s*=\s*TortoiseBots[^\n]*\n)', r'\1local L = TB.L\n', out, count=1, flags=re.M)
        if not n:
            print(f"{path.name}: no 'local TB = TortoiseBots' line, add 'local L = TB.L' by hand")
    if write and out != src:
        if crlf:
            out = out.replace("\n", "\r\n")
        path.write_bytes(out.encode("utf-8"))
    print(f"{path.name}: {wrapped} wrapped, {len(skipped)} skipped, {len(concat)} concatenated")
    for no, text in skipped:
        print(f"  skip   {path.name}:{no}: {text}")
    for no, text in concat:
        print(f"  concat {path.name}:{no}: {text[:160]}")


def main():
    write = "--write" in sys.argv
    files = [a for a in sys.argv[1:] if a != "--write"]
    for f in files:
        process(pathlib.Path(f), write)


if __name__ == "__main__":
    main()
