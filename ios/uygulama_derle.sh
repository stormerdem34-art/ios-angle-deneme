#!/bin/bash
set -euo pipefail

KOK="$(cd "$(dirname "$0")/.." && pwd)"
ANGLE="$KOK/angle-cikti"
YAPI="$KOK/yapi"
UYG="$YAPI/Payload/MSP2Deneme.app"

rm -rf "$YAPI" "$KOK/MSP2Deneme.ipa"
mkdir -p "$UYG/Frameworks"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun -sdk iphoneos clang++ -arch arm64 -miphoneos-version-min=16.0 -isysroot "$SDK" \
  -std=c++17 -fobjc-arc -O2 -Wall \
  -I "$ANGLE/include" -F "$ANGLE" \
  "$KOK/ios/uygulama/main.mm" \
  -framework libEGL -framework libGLESv2 \
  -framework UIKit -framework QuartzCore -framework Metal -framework CoreGraphics -framework Foundation \
  -Wl,-rpath,@executable_path/Frameworks \
  -o "$UYG/MSP2Deneme"

cp "$KOK/ios/uygulama/Info.plist" "$UYG/Info.plist"
plutil -lint "$UYG/Info.plist"
plutil -convert binary1 "$UYG/Info.plist"
cp -R "$ANGLE/libEGL.framework" "$ANGLE/libGLESv2.framework" "$UYG/Frameworks/"
cp "$ANGLE/ANGLE_LICENSE" "$UYG/ANGLE_LICENSE"

otool -L "$UYG/MSP2Deneme"
lipo -info "$UYG/MSP2Deneme"

cd "$YAPI"
zip -qry "$KOK/MSP2Deneme.ipa" Payload
ls -la "$KOK/MSP2Deneme.ipa"
