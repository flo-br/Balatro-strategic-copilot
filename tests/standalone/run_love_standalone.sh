#!/bin/sh
# Autonomous mode on the REAL LÖVE runtime: builds a fused executable (LÖVE + simulated Balatro
# archive, like Balatro.exe), then runs it with different save folders (the equivalent of
# %AppData%\Balatro), under Xvfb.
# usage: tests/standalone/run_love_standalone.sh <package.zip> [work_dir]
set -e
REPO=$(cd "$(dirname "$0")/../.." && pwd)
ZIP=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
WORK=${2:-$(mktemp -d)}
mkdir -p "$WORK"
LOVE=$(readlink -f "$(command -v love)")
rm -f "$WORK/mock.love"
(cd "$REPO/tests/standalone/mock_balatro" && zip -q -r "$WORK/mock.love" .)
cat "$LOVE" "$WORK/mock.love" > "$WORK/Balatro"
chmod +x "$WORK/Balatro"
rm -rf "$WORK/pkg" && mkdir -p "$WORK/pkg" && (cd "$WORK/pkg" && unzip -q "$ZIP")
SRC="$WORK/pkg/COPIER_DANS_AppData_Balatro"

for scen in autonome sans_amorce sans_mod smods append; do
    data="$WORK/data_$scen"; save="$data/Balatro"
    rm -rf "$data"; mkdir -p "$save"
    case $scen in
        autonome|append) cp -r "$SRC/." "$save/" ;;
        sans_amorce) mkdir -p "$save/Mods" && cp -r "$SRC/Mods/BalatroStrategicCopilot" "$save/Mods/" ;;
        sans_mod) cp "$SRC/main.lua" "$save/" ;;
        smods) cp -r "$SRC/." "$save/" ;;
    esac
    XDG_DATA_HOME="$data" BSC_REPO="$REPO" BSC_SCENARIO=$scen \
        timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" "$WORK/Balatro" >"$WORK/out_$scen.txt" 2>&1 || true
    echo "=== $scen"
    if [ -f "$save/mock_result.txt" ]; then sed 's/^/  /' "$save/mock_result.txt"; else echo "  (no mock_result.txt)"; fi
    if [ -f "$save/BSC/amorce.log" ]; then sed 's/^[0-9-]* [0-9:]*  /  amorce: /' "$save/BSC/amorce.log" | tr -d '\r'; else echo "  amorce: (no amorce.log)"; fi
done
echo "work dir: $WORK"
