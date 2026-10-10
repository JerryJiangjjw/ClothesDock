#!/usr/bin/env python3
"""Verify release version/tag and bundle metadata contracts."""
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
VERSION = (ROOT / 'VERSION').read_text().strip()


def run(*args, build='1'):
    return subprocess.run(['python3', str(ROOT / 'scripts/version.py'), *args],
                          env={**os.environ, 'BUILD_NUMBER': build}, capture_output=True, text=True)


class ReleaseTests(unittest.TestCase):
    def test_matching_tag_and_mismatch(self):
        self.assertEqual(run('--tag', 'v' + VERSION).returncode, 0)
        self.assertNotEqual(run('--tag', 'v999.999.999').returncode, 0)
        self.assertNotEqual(run('--tag', VERSION).returncode, 0)

    def test_bundle_version_and_build_number_come_from_release_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'Info.plist'
            result = run('--write-plist', str(target), build='42')
            self.assertEqual(result.returncode, 0, result.stderr)
            with target.open('rb') as file:
                info = plistlib.load(file)
            self.assertEqual(info['CFBundleShortVersionString'], VERSION)
            self.assertEqual(info['CFBundleVersion'], '42')
            self.assertEqual(info['CFBundleExecutable'], 'ClothesDock')
            self.assertEqual(info['CFBundleIconFile'], 'AppIcon')

    def test_invalid_build_number_cannot_produce_a_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'Info.plist'
            result = run('--write-plist', str(target), build='not-a-number')
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(target.exists())


if __name__ == '__main__':
    unittest.main()
