#!/bin/zsh
# Crea build/ClamMac-<versión>.dmg: instalador con ClamMac.app + acceso directo a Aplicaciones,
# con el icono de la caja (InstallerIcon) en el volumen y en el propio .dmg.
# Firma con Developer ID y NOTARIZA app y DMG (perfil de notarytool en el llavero; SKIP_NOTARIZE=1 para omitir).
set -e
cd "${0:A:h}"
SIGN_HASH="F211AC309817AB7AE7332B19F29F294C19C40AA0"
VERSION=$(grep -E '^VERSION=' build_app.sh | cut -d'"' -f2)
NOTARY_PROFILE="${NOTARY_PROFILE:-cephaloplan}"
DMG="build/ClamMac-$VERSION.dmg"
STAGE="build/dmg-stage"

./build_app.sh

notarize() {   # $1 = fichero (.zip o .dmg)
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait
}
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
  ditto -c -k --sequesterRsrc --keepParent build/ClamMac.app build/ClamMac-notar.zip
  notarize build/ClamMac-notar.zip
  rm -f build/ClamMac-notar.zip
  xcrun stapler staple build/ClamMac.app
fi
rm -rf "$STAGE" "$DMG"; mkdir -p "$STAGE"
cp -R build/ClamMac.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
sed "s/__VERSION__/$VERSION/g" Installer/Leeme.template.html > "$STAGE/Léeme.html"
cp Icon/InstallerIcon.icns "$STAGE/.VolumeIcon.icns"
SetFile -a C "$STAGE"
hdiutil create -volname "ClamMac" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --timestamp --sign "$SIGN_HASH" "$DMG"
swift Icon/seticon.swift Icon/InstallerIcon.icns "$DMG"
if [[ "${SKIP_NOTARIZE:-0}" != "1" ]]; then
  notarize "$DMG"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
  spctl -a -t open --context context:primary-signature -v "$DMG"
fi
shasum -a 256 "$DMG"
echo "OK → $DMG"
