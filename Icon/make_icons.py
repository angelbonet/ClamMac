"""Convierte los dos PNG de diseño (724x724 con fondo gris y sombra) en iconos macOS con transparencia.
 src/clamav-grafito.png    -> AppIcon.icns        (app / Dock)
 src/clamav-instalador.png -> InstallerIcon.icns  (DMG / instalador)
La silueta se extrae de la propia imagen (relleno desde el borde), no se aproxima con una fórmula.
Uso: python3 make_icons.py"""
import os, subprocess
from collections import deque
import numpy as np
from PIL import Image, ImageFilter

S = 2048

def flood(binary, seeds):
    h, w = binary.shape
    out = np.zeros((h, w), dtype=bool); q = deque()
    for (x, y) in seeds:
        if binary[y, x] and not out[y, x]: out[y, x] = True; q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if 0 <= nx < w and 0 <= ny < h and binary[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True; q.append((nx, ny))
    return out

def body_mask(rgb, kind):
    a = rgb.astype(int)
    if kind == "dark":      # cuerpo oscuro: fondo y sombra son claros
        outside_like = a.min(axis=2) >= 120
    else:                   # cuerpo azulado: fondo y sombra son grises neutros
        outside_like = np.abs(a[:, :, 2] - a[:, :, 0]) <= 2
    h, w = outside_like.shape
    border = [(x, 0) for x in range(w)] + [(x, h-1) for x in range(w)] + [(0, y) for y in range(h)] + [(w-1, y) for y in range(h)]
    outside = flood(outside_like, border)
    body = ~outside
    # quedarse con la componente principal (descarta motas) y rellenar huecos
    main = flood(body, [(w // 2, h // 2)])
    outside2 = flood(~main, border)
    return ~outside2

def build(src, name, kind):
    rgb = np.asarray(Image.open(src).convert("RGB"))
    m = body_mask(rgb, kind)
    alpha = Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    im = Image.fromarray(rgb).convert("RGBA"); im.putalpha(alpha)
    im = im.crop(alpha.point(lambda v: 255 if v > 8 else 0).getbbox())
    body = int(824 * S / 1024)
    im = im.resize((body, body), Image.LANCZOS)
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0)); x0 = (S - body) // 2
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sh.paste((0, 0, 0, 120), (x0, x0 + int(12 * S / 1024)), im.split()[3])
    canvas = Image.alpha_composite(canvas, sh.filter(ImageFilter.GaussianBlur(int(14 * S / 1024))))
    canvas.alpha_composite(im, (x0, x0))
    final = canvas.resize((1024, 1024), Image.LANCZOS)
    final.save(f"{name}_1024.png")
    iconset = f"{name}.iconset"; os.makedirs(iconset, exist_ok=True)
    for base in (16, 32, 128, 256, 512):
        final.resize((base, base), Image.LANCZOS).save(f"{iconset}/icon_{base}x{base}.png")
        final.resize((base * 2, base * 2), Image.LANCZOS).save(f"{iconset}/icon_{base}x{base}@2x.png")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", f"{name}.icns"], check=True)
    subprocess.run(["rm", "-rf", iconset])

build("src/clamav-grafito.png", "AppIcon", "dark")
build("src/clamav-instalador.png", "InstallerIcon", "tint")
print("OK")
