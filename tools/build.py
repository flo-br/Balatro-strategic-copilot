#!/usr/bin/env python3
"""Build the installable package: dist/BalatroStrategicCopilot-<version>.zip

Contents (no top-level folder, so that Windows "Extract all" gives one folder):
  INSTALLER_COPILOT.bat     double-click: checks/repairs Lovely, Steamodded, installs the mod
  DIAGNOSTIC_COPILOT.bat    same checks without changing anything
  LISEZ-MOI.txt             3-step instructions
  outils/installer_copilot.ps1
  BalatroStrategicCopilot/  the mod itself (what ends up in %AppData%/Balatro/Mods/)

Old Steamodded versions (1.0.0~BETA-0509c, checked with tools/smods_loader_check.lua) ignore a
zip dropped as is in Mods: it must be extracted (the installer does the right thing).
Windows files get CRLF line endings; the PowerShell script and the .txt files get a UTF-8 BOM
(required by Windows PowerShell 5.1 to read accented characters correctly).
"""
import json
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, 'BalatroStrategicCopilot')
INSTALLER = os.path.join(ROOT, 'installer')
DIST = os.path.join(ROOT, 'dist')
ALLOWED = ('.lua', '.json', '.txt')
BOM = b'\xef\xbb\xbf'


def crlf(data):
    return data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')


def windows_text(path):
    with open(path, 'rb') as f:
        data = f.read()
    if path.endswith(('.ps1', '.txt')):  # BOM: accents read correctly by PowerShell 5.1 and old Notepad
        if not data.startswith(BOM):
            data = BOM + data
        return crlf(data)
    if path.endswith('.bat'):
        data.decode('ascii')  # cmd.exe: keep batch files pure ASCII
        return crlf(data)
    return data


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
                data = windows_text(full) if name.endswith('.txt') else open(full, 'rb').read()
                z.writestr(rel, data)
                count += 1
        for rel in ('INSTALLER_COPILOT.bat', 'DIAGNOSTIC_COPILOT.bat', 'LISEZ-MOI.txt', 'outils/installer_copilot.ps1'):
            z.writestr(rel, windows_text(os.path.join(INSTALLER, *rel.split('/'))))
            count += 1
    print('%s (%d files)' % (out, count))
    return 0


if __name__ == '__main__':
    sys.exit(main())
