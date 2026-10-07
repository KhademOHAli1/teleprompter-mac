#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create a reproducible selected-file ZIP, excluding generated/user data."""
from pathlib import Path
import argparse
import importlib.util
import plistlib
import stat
import zipfile


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    spec = importlib.util.spec_from_file_location("check_source", root / "scripts/check-source.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    files = checker.validate(root)
    with (root / "Info.plist").open("rb") as handle:
        version = plistlib.load(handle)["CFBundleShortVersionString"]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=root / "dist" / f"teleprompter-source-v{version}.zip")
    destination = parser.parse_args().output.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination in files:
        raise SystemExit("Archive output must not replace a source file.")
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            relative = path.relative_to(root).as_posix()
            info = zipfile.ZipInfo("teleprompter/" + relative, date_time=(2026, 10, 7, 0, 0, 0))
            info.create_system = 3
            mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, path.read_bytes())
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None or len(archive.namelist()) != len(files):
            raise SystemExit("Archive integrity check failed.")
    print(f"Created {destination.name}: {len(files)} source files.")


if __name__ == "__main__":
    main()
