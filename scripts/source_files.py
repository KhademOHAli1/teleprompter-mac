#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Select publishable project files without consulting Git or user settings."""
from pathlib import Path

ROOT_FILES = (
    ".gitattributes", ".gitignore", "LICENSE", "README.md", "README.de.md",
    "CONTRIBUTING.md", "SECURITY.md", "CHANGELOG.md", "Info.plist",
    "build.command", "test.command", "start.command", "examples/demo-de.txt",
)
TREES = {
    "Sources": {".swift"},
    "Tests": {".swift", ".py"},
    "scripts": {".py", ".sh"},
    "docs": {".md"},
    ".github": {".yml", ".md"},
}


def project_files(root: Path) -> list[Path]:
    selected = []
    for relative in ROOT_FILES:
        path = root / relative
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Missing file or symlink: {relative}")
        selected.append(path)
    for directory, extensions in TREES.items():
        tree = root / directory
        if tree.is_symlink() or not tree.is_dir():
            raise ValueError(f"Missing directory or symlink: {directory}")
        for path in sorted(tree.rglob("*")):
            relative = path.relative_to(root)
            if "__pycache__" in path.parts or path.name == ".DS_Store" or path.name.startswith("._"):
                continue
            if path.is_symlink():
                raise ValueError(f"Symlink is not publishable: {relative}")
            if path.is_dir():
                continue
            if path.suffix not in extensions:
                raise ValueError(f"Unexpected source-package file: {relative}")
            selected.append(path)
    return sorted(selected, key=lambda path: path.relative_to(root).as_posix())
