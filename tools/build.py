#!/usr/bin/env python3
"""Build the installable package: dist/BalatroStrategicCopilot-<version>.zip

The archive contains a single folder, BalatroStrategicCopilot/, to copy into
%AppData%/Balatro/Mods/ (Steamodded can also load the zip directly).
Only the mod files are packaged (no tests, no tools, no development files).
"""
import json
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, 'BalatroStrategicCopilot')
DIST = os.path.join(ROOT, 'dist')
ALLOWED = ('.lua', '.json', '.txt')


def main():
    with open(os.path.join(MOD, 'BalatroStrategicCopilot.json'), encoding='utf-8') as f:
        meta = json.load(f)
    version = meta['version']
    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, 'BalatroStrategicCopilot-%s.zip' % version)
    count = 0
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for base, dirs, files in os.walk(MOD):
            dirs.sort()
            for name in sorted(files):
                if not name.endswith(ALLOWED):
                    continue
                full = os.path.join(base, name)
                rel = os.path.relpath(full, os.path.dirname(MOD)).replace(os.sep, '/')
                z.write(full, rel)
                count += 1
    print('%s (%d files)' % (out, count))
    return 0


if __name__ == '__main__':
    sys.exit(main())
