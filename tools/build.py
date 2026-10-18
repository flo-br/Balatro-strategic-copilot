#!/usr/bin/env python3
"""Build the installable packages in dist/:

1. BalatroStrategicCopilot-<version>.zip  - NO script, NO DLL (works on locked-down PCs):
     LISEZ-MOI.txt
     COPIER_DANS_AppData_Balatro/main.lua                       autonomous-mode bootstrap
     COPIER_DANS_AppData_Balatro/Mods/BalatroStrategicCopilot/  the mod
   The content of COPIER_DANS_AppData_Balatro is copied as is into %AppData%/Balatro/.
   With Lovely + Steamodded, Steamodded loads the mod from Mods/ and the bootstrap stays out.

2. BalatroStrategicCopilot-<version>-installateur.zip  - for PCs that allow scripts:
     INSTALLER_COPILOT.bat, DIAGNOSTIC_COPILOT.bat, LISEZ-MOI.txt, outils/installer_copilot.ps1
     BalatroStrategicCopilot/   (checks/repairs Lovely, Steamodded and installs the mod)

Old Steamodded versions (1.0.0~BETA-0509c, checked with tools/smods_loader_check.lua) ignore a
zip dropped as is in Mods: it must be extracted.
Windows text files get CRLF line endings; the PowerShell script and the .txt files get a UTF-8
BOM (required by Windows PowerShell 5.1 / old Notepad for accents). Lua files are left untouched
(a BOM would break them).
"""
import json
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, 'BalatroStrategicCopilot')
INSTALLER = os.path.join(ROOT, 'installer')
STANDALONE = os.path.join(ROOT, 'standalone')
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


def add_mod(z, prefix):
    count = 0
    for base, dirs, files in os.walk(MOD):
        dirs.sort()
        for name in sorted(files):
            if not name.endswith(ALLOWED):
                continue
            full = os.path.join(base, name)
            rel = os.path.relpath(full, os.path.dirname(MOD)).replace(os.sep, '/')
            data = windows_text(full) if name.endswith('.txt') else open(full, 'rb').read()
            z.writestr(prefix + rel, data)
            count += 1
    return count


def main():
    with open(os.path.join(MOD, 'BalatroStrategicCopilot.json'), encoding='utf-8') as f:
        meta = json.load(f)
    version = meta['version']
    os.makedirs(DIST, exist_ok=True)

    out = os.path.join(DIST, 'BalatroStrategicCopilot-%s.zip' % version)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('LISEZ-MOI.txt', windows_text(os.path.join(STANDALONE, 'LISEZ-MOI.txt')))
        with open(os.path.join(STANDALONE, 'main.lua'), 'rb') as f:
            z.writestr('COPIER_DANS_AppData_Balatro/main.lua', f.read())
        count = 2 + add_mod(z, 'COPIER_DANS_AppData_Balatro/Mods/')
    print('%s (%d files)' % (out, count))

    out = os.path.join(DIST, 'BalatroStrategicCopilot-%s-installateur.zip' % version)
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        count = add_mod(z, '')
        for rel in ('INSTALLER_COPILOT.bat', 'DIAGNOSTIC_COPILOT.bat', 'LISEZ-MOI.txt', 'outils/installer_copilot.ps1'):
            z.writestr(rel, windows_text(os.path.join(INSTALLER, *rel.split('/'))))
            count += 1
    print('%s (%d files)' % (out, count))
    return 0


if __name__ == '__main__':
    sys.exit(main())
