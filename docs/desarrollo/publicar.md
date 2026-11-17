# Publicar una versión

1. Sube `VERSION` en `build_app.sh` (`MAJOR.MINOR.PATCH`).
2. Añade la entrada en `CHANGELOG.md`.
3. Haz *commit* y *push* a `main` (el script se niega a publicar con cambios sin commitear).
4. Mantén el Mac **desbloqueado** (ver [Compilar y firmar](compilar.md)) y ejecuta:

```bash
./release.sh "Notas de la versión"
```

`release.sh`:

- compila, firma y **notariza** el DMG (`build_dmg.sh`; con `SKIP_BUILD=1` reutiliza el ya generado);
- comprueba que **no existe** ya esa versión y que el DMG está **notarizado** (si no, aborta sin publicar);
- calcula el **SHA-256** y lo incluye en las notas;
- crea la *release* y el *tag* `vX.Y.Z` con `gh` y sube el DMG como adjunto.

## Qué hacen los usuarios con esa release

Las apps instaladas consultan `releases/latest` una vez al día. Si la versión es más nueva, ofrecen **Actualizar y reiniciar** tras verificar SHA-256, firma, notarización y versión. El SHA-256 se toma del campo `digest` del adjunto o, si falta, de las notas (`SHA-256: <64 hex>`), por eso `release.sh` lo escribe siempre.

!!! warning "No publiques como pre-release ni borrador"
    El comprobador ignora `draft` y `prerelease`; una release marcada así no se ofrecerá a nadie.

## Comprobar después de publicar

```bash
CLAMMAC_LIVE=1 swift test --filter testLiveGitHubRelease
```

Descarga la release real y verifica hash, firma y notarización.
