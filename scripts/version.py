#!/usr/bin/env python3
"""Single version source for local builds, tags and release assets."""
import argparse
import os
from pathlib import Path
import plistlib
import re

ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / 'VERSION'


def validate(value):
    if not re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', value):
        raise ValueError('Version must be MAJOR.MINOR.PATCH without leading zeros')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--set', dest='new_version', help='Set the next version')
    parser.add_argument('--tag', help='Require an exact vVERSION tag match')
    parser.add_argument('--write-plist', type=Path, help='Render the application Info.plist')
    args = parser.parse_args()
    try:
        version = validate(args.new_version or VERSION_FILE.read_text().strip())
        if args.tag and args.tag != 'v' + version:
            raise ValueError(f'Tag {args.tag!r} does not match VERSION ({version})')
        build_number = os.environ.get('BUILD_NUMBER', '1')
        if not re.fullmatch(r'[1-9]\d*', build_number):
            raise ValueError('BUILD_NUMBER must be a positive integer')
        if args.new_version:
            VERSION_FILE.write_text(version + '\n')
        if args.write_plist:
            with (ROOT / 'scripts/Info.plist').open('rb') as source:
                info = plistlib.load(source)
            info['CFBundleShortVersionString'] = version
            info['CFBundleVersion'] = build_number
            with args.write_plist.open('wb') as output:
                plistlib.dump(info, output)
        print(version)
    except (ValueError, OSError) as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
