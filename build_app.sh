#!/bin/zsh
# Compila ClamMac en release (binario UNIVERSAL: Apple Silicon + Intel), crea ClamMac.app y lo firma con Developer ID (cuenta personal de Ángel Bonet).
# Uso: ./build_app.sh [--install]   (--install copia a /Applications)
set -e
cd "${0:A:h}"
SIGN_HASH="DD3894D51C0CD7431CB40011799962688668037D"
APP="build/ClamMac.app"
VERSION="1.1.1"

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ClamMac
[[ "$(lipo -archs "$BIN" | tr ' ' '\n' | sort | tr '\n' ' ')" == "arm64 x86_64 " ]] || { echo "El binario no es universal"; exit 1; }

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
 <key>NSHumanReadableCopyright</key><string>© Ángel Bonet · ABDatabase</string>
</dict></plist>
PLIST

# --- Motor ClamAV incluido (universal, estático): Engine/build_clamav.sh lo genera en build/engine/universal ---
ENG="build/engine/universal"
[[ -x "$ENG/clamscan" ]] || { echo "Falta el motor universal: ejecuta Engine/build_clamav.sh"; exit 1; }
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/Resources/Licenses"
for b in clamscan clamdscan clamd freshclam; do
  cp "$ENG/$b" "$APP/Contents/Helpers/$b"
  strip -x "$APP/Contents/Helpers/$b" 2>/dev/null || true
  [[ "$(lipo -archs "$APP/Contents/Helpers/$b" | tr ' ' '\n' | sort | tr '\n' ' ')" == "arm64 x86_64 " ]] || { echo "$b no es universal"; exit 1; }
  codesign --force --options runtime --timestamp --identifier "com.abdatabase.clammac.$b" --sign "$SIGN_HASH" "$APP/Contents/Helpers/$b"
done
S="build/engine/src"
cp "$S"/clamav-*/COPYING.txt "$APP/Contents/Resources/Licenses/ClamAV-GPLv2.txt"
cp -R "$S"/clamav-*/COPYING "$APP/Contents/Resources/Licenses/ClamAV-componentes"
cp "$S"/openssl-*/LICENSE.txt "$APP/Contents/Resources/Licenses/OpenSSL-Apache2.txt"
cp "$S"/pcre2-*/LICENCE.md "$APP/Contents/Resources/Licenses/PCRE2.txt"
cp "$S"/json-c-*/COPYING "$APP/Contents/Resources/Licenses/json-c-MIT.txt"
mkdir -p "$APP/Contents/Resources/certs"; cp "$S"/clamav-*/certs/clamav.crt "$APP/Contents/Resources/certs/clamav.crt"
cp Engine/LEEME-LICENCIAS.txt "$APP/Contents/Resources/Licenses/LEEME.txt"

codesign --force --options runtime --timestamp --sign "$SIGN_HASH" "$APP"
codesign --verify --strict --deep --verbose=2 "$APP"
echo "OK → $APP"
if [[ "$1" == "--install" ]]; then
  rm -rf /Applications/ClamMac.app; cp -R "$APP" /Applications/ClamMac.app
  echo "Instalada en /Applications/ClamMac.app"
fi
