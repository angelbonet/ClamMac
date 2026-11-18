#!/bin/zsh
# Publica una release en GitHub: compila + notariza el DMG (./build_dmg.sh) y lo sube con su SHA-256.
# Uso: ./release.sh "Notas de la versión"      (SKIP_BUILD=1 reutiliza el DMG ya generado)
set -e
cd "${0:A:h}"
VERSION=$(grep -E '^VERSION=' build_app.sh | cut -d'"' -f2)
TAG="v$VERSION"; DMG="build/ClamMac-$VERSION.dmg"
[[ -z "$(git status --porcelain)" ]] || { echo "Hay cambios sin commitear: haz commit antes de publicar."; exit 1; }
gh release view "$TAG" >/dev/null 2>&1 && { echo "La release $TAG ya existe. Sube VERSION en build_app.sh."; exit 1; }
[[ "${SKIP_BUILD:-0}" == "1" ]] || ./build_dmg.sh
[[ -f "$DMG" ]] || { echo "No existe $DMG"; exit 1; }
spctl -a -t open --context context:primary-signature -v "$DMG" 2>&1 | grep -q "Notarized Developer ID" || { echo "El DMG no está notarizado; no se publica."; exit 1; }
SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
NOTES="${1:-ClamMac $VERSION}

**SHA-256:** \`$SHA\`

Firmado con Developer ID de Ángel Bonet (desarrollador independiente) y notarizado por Apple. Requiere macOS 14+. El motor antivirus ClamAV va incluido."
gh release create "$TAG" "$DMG" --target "$(git rev-parse --abbrev-ref HEAD)" --title "ClamMac $VERSION" --notes "$NOTES" --latest
echo "Publicada: $(gh release view "$TAG" --json url --jq .url)"
