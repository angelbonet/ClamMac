#!/bin/zsh
# Compila ClamMac en release, crea ClamMac.app y lo firma con Developer ID (G2 de Innovaorto).
# Uso: ./build_app.sh [--install]   (--install copia a /Applications)
set -e
cd "${0:A:h}"
SIGN_HASH="F211AC309817AB7AE7332B19F29F294C19C40AA0"
APP="build/ClamMac.app"
VERSION="1.0.2"

swift build -c release
BIN=$(swift build -c release --show-bin-path)/ClamMac

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ClamMac"
cp Icon/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>CFBundleIdentifier</key><string>com.abdatabase.clammac</string>
 <key>CFBundleName</key><string>ClamMac</string>
 <key>CFBundleDisplayName</key><string>ClamMac</string>
 <key>CFBundleIconFile</key><string>AppIcon</string>
 <key>CFBundleExecutable</key><string>ClamMac</string>
 <key>CFBundlePackageType</key><string>APPL</string>
 <key>CFBundleShortVersionString</key><string>$VERSION</string>
 <key>CFBundleVersion</key><string>1</string>
 <key>LSMinimumSystemVersion</key><string>14.0</string>
 <key>LSUIElement</key><true/>
 <key>NSHighResolutionCapable</key><true/>
 <key>NSHumanReadableCopyright</key><string>© Ángel Bonet · ABDatabase / INNOVAORTO AIE</string>
</dict></plist>
PLIST

codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "OK → $APP"
if [[ "$1" == "--install" ]]; then
  rm -rf /Applications/ClamMac.app; cp -R "$APP" /Applications/ClamMac.app
  echo "Instalada en /Applications/ClamMac.app"
fi
