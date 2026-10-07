# SPDX-License-Identifier: MIT
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT / "scripts"))
from source_files import ROOT_FILES, TREES, project_files

spec = importlib.util.spec_from_file_location("check_source", PROJECT / "scripts/check-source.py")
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class SourcePackagingTests(unittest.TestCase):
    def fixture(self, root):
        for name in ROOT_FILES:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("neutral\n", encoding="utf-8")
        for directory in TREES:
            (root / directory).mkdir(exist_ok=True)
        (root / "Sources/Demo.swift").write_text("// neutral\n", encoding="utf-8")

    def test_generated_files_and_credentials_are_excluded(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            for name in (".env", "private/script.txt", ".git/config", ".build/cache", "dist/Example.app/binary"):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("not publishable", encoding="utf-8")
            names = {path.relative_to(root).as_posix() for path in project_files(root)}
            self.assertEqual(names, set(ROOT_FILES) | {"Sources/Demo.swift"})

    def test_missing_required_file_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            (root / "LICENSE").unlink()
            with self.assertRaises(ValueError):
                project_files(root)

    def test_source_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            (root / "Sources/Linked.swift").symlink_to(root / "LICENSE")
            with self.assertRaises(ValueError):
                project_files(root)

    def test_recording_inside_source_tree_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            (root / "Sources/voice.wav").write_bytes(b"audio")
            with self.assertRaises(ValueError):
                project_files(root)

    def test_secret_and_home_path_patterns_are_detected(self):
        fake_key = "sk" + "-" + "not-a-real-credential" * 2
        home_path = "/" + "Users/" + "someone/private.txt"
        private_key = "-----BEGIN " + "PRIVATE KEY-----"
        self.assertEqual(len(checker.scan_text(fake_key + home_path + private_key)), 3)

    def test_safe_code_and_urls_pass(self):
        self.assertEqual(checker.scan_text("let model = \"gpt-live-transcribe\"\nhttps://example.com"), [])


if __name__ == "__main__":
    unittest.main()
