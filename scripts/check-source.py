#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Limited source-only privacy/hygiene checks. Never reads app preferences."""
from pathlib import Path
import re
import sys

from source_files import project_files

PATTERNS = {
    "possible API key": re.compile(r"sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}"),
    "private-key material": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "machine-specific home path": re.compile(r"/(?:Users|home)/[A-Za-z0-9_.-]+"),
}


def scan_text(text: str) -> list[str]:
    return [name for name, pattern in PATTERNS.items() if pattern.search(text)]


def validate(root: Path) -> list[Path]:
    files = project_files(root)
    errors = []
    for path in files:
        relative = path.relative_to(root)
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeError, OSError):
            errors.append(f"{relative}: unreadable or non-UTF-8 source")
            continue
        errors.extend(f"{relative}: {reason}" for reason in scan_text(text))
        if path.suffix in {".swift", ".sh", ".py", ".command"} and "SPDX-License-Identifier: MIT" not in text:
            errors.append(f"{relative}: missing MIT SPDX identifier")
        if path.suffix in {".sh", ".command"} and not path.stat().st_mode & 0o111:
            errors.append(f"{relative}: script is not executable")
        if path.suffix == ".md":
            for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
                if target.startswith(("https://", "http://", "#")):
                    continue
                destination = (path.parent / target.split("#", 1)[0]).resolve()
                if not destination.is_file():
                    errors.append(f"{relative}: broken relative link {target}")
    if "MIT License" not in (root / "LICENSE").read_text(encoding="utf-8"):
        errors.append("LICENSE: expected MIT license")
    if errors:
        raise ValueError("\n".join(errors))
    return files


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    try:
        files = validate(root)
    except ValueError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
    print(f"Source hygiene passed: {len(files)} selected text files; no detected keys or home paths.")


if __name__ == "__main__":
    main()
