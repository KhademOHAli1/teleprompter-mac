# SPDX-License-Identifier: MIT
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent.parent
class LocalizationResourceTests(unittest.TestCase):
    def test_complete_platform_catalogues_and_placeholders(self):
        tables = {language: json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(ROOT / 'Resources' / (language + '.lproj') / 'Localizable.strings')])) for language in ('en', 'de', 'fr', 'es')}
        for language, table in tables.items():
            self.assertEqual(set(table), set(tables['en']), language)
            for key, value in table.items():
                self.assertTrue(value, (language, key))
                self.assertEqual(re.findall(r'\{\d+\}', value), re.findall(r'\{\d+\}', tables['en'][key]), (language, key))
    def test_permission_strings_are_localized_and_bundled(self):
        for language in ('en', 'de', 'fr', 'es'):
            folder = ROOT / 'Resources' / (language + '.lproj')
            table = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(folder / 'InfoPlist.strings')]))
            self.assertTrue(table['NSMicrophoneUsageDescription'])
            self.assertTrue(table['NSSpeechRecognitionUsageDescription'])
            self.assertTrue((folder / 'Demo.txt').read_text().strip())
