#!/usr/bin/env python3
"""Set Steam per-app LaunchOptions in userdata/*/config/localconfig.vdf.

This intentionally edits only an existing app block. It creates a timestamped
backup unless --dry-run is used.
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from datetime import datetime
from pathlib import Path


def die(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def vdf_escape(value: str) -> str:
    return value.replace('\\', '\\\\').replace('"', '\\"')


def find_matching_brace(text: str, open_index: int) -> int:
    depth = 0
    in_string = False
    escape = False
    for i in range(open_index, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return i
    raise ValueError("could not find matching closing brace in VDF")


def update_launch_options(text: str, appid: str, launch_options: str) -> tuple[str, str | None]:
    app_match = re.search(rf'(?m)^([ \t]*)"{re.escape(appid)}"[ \t]*\r?\n[ \t]*\{{', text)
    if not app_match:
        die(f'app block "{appid}" not found in localconfig.vdf')
    assert app_match is not None

    block_open = text.find('{', app_match.end() - 2)
    block_close = find_matching_brace(text, block_open)
    block = text[block_open + 1:block_close]
    escaped = vdf_escape(launch_options)

    option_re = re.compile(r'(?m)^([ \t]*)"LaunchOptions"[ \t]*"((?:\\.|[^"\\])*)"')
    option_match = option_re.search(block)
    if option_match:
        old = option_match.group(2).replace('\\"', '"').replace('\\\\', '\\')
        replacement = f'{option_match.group(1)}"LaunchOptions"\t\t"{escaped}"'
        new_block = block[:option_match.start()] + replacement + block[option_match.end():]
    else:
        old = None
        # Match the app block's existing indentation style. Steam commonly uses one extra tab inside.
        app_indent = app_match.group(1)
        insert = f'\n{app_indent}\t\t\t"LaunchOptions"\t\t"{escaped}"'
        new_block = block.rstrip('\r\n') + insert + block[len(block.rstrip('\r\n')):]

    return text[:block_open + 1] + new_block + text[block_close:], old


def main() -> None:
    parser = argparse.ArgumentParser(description="Set Steam launch options for one app in localconfig.vdf")
    parser.add_argument("--localconfig", required=True, type=Path)
    parser.add_argument("--appid", default="730")
    parser.add_argument("--launch-options", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    path = args.localconfig.expanduser()
    if not path.is_file():
        die(f"localconfig.vdf not found: {path}")

    original = path.read_text(encoding="utf-8", errors="surrogateescape")
    updated, old = update_launch_options(original, args.appid, args.launch_options)

    print(f"localconfig: {path}")
    print(f"appid: {args.appid}")
    print(f"old LaunchOptions: {old if old is not None else '<missing>'}")
    print(f"new LaunchOptions: {args.launch_options}")

    if updated == original:
        print("No change needed.")
        return

    if args.dry_run:
        print("Dry run: localconfig.vdf not modified.")
        return

    backup = path.with_name(path.name + ".bak." + datetime.now().strftime("%Y%m%d-%H%M%S"))
    shutil.copy2(path, backup)
    path.write_text(updated, encoding="utf-8", errors="surrogateescape")
    print(f"Backup written: {backup}")
    print("Launch options updated. Restart Steam if it was open.")


if __name__ == "__main__":
    main()
