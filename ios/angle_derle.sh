#!/bin/bash
set -euo pipefail

KOK="$(cd "$(dirname "$0")/.." && pwd)"
dal="$(grep '^dal=' "$KOK/ios/angle_surum.txt" | cut -d= -f2)"
isle="$(grep '^isle=' "$KOK/ios/angle_surum.txt" | cut -d= -f2)"
depot="$(grep '^depot_tools=' "$KOK/ios/angle_surum.txt" | cut -d= -f2)"
CALISMA="$KOK/calisma"
CIKTI="$KOK/angle-cikti"
mkdir -p "$CALISMA" "$CIKTI"

cd "$CALISMA"
if [ ! -d depot_tools ]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git depot_tools
  git -C depot_tools checkout "$depot"
fi
export PATH="$CALISMA/depot_tools:$PATH"
export DEPOT_TOOLS_UPDATE=0

if [ ! -d angle ]; then
  git clone --branch "$dal" --single-branch https://github.com/google/angle angle
fi
cd angle
git checkout "$isle"
python3 scripts/bootstrap.py
gclient sync

gn gen out/ios --args='is_component_build=false is_debug=false angle_enable_wgpu=false target_cpu="arm64" target_os="ios" target_environment="device" ios_enable_code_signing=false'
autoninja -C out/ios libEGL libGLESv2

for f in libEGL libGLESv2; do
  rm -rf "$CIKTI/$f.framework"
  cp -R "out/ios/$f.framework" "$CIKTI/"
  plutil -replace CFBundleShortVersionString -string 1.0 "$CIKTI/$f.framework/Info.plist"
  otool -D "$CIKTI/$f.framework/$f"
done
rm -rf "$CIKTI/include"
cp -R include "$CIKTI/include"
cp LICENSE "$CIKTI/ANGLE_LICENSE"
echo "$isle" > "$CIKTI/surum.txt"
