#!/bin/bash
# Compila ClamAV ESTÁTICO y UNIVERSAL (arm64 + x86_64) para llevarlo dentro de ClamMac.app.
# Salida: build/engine/universal/{clamscan,clamdscan,clamd,freshclam,sigtool} + licencias.
# Uso: Engine/build_clamav.sh            (ambas arquitecturas)
#      Engine/build_clamav.sh arm64      (una sola; sin lipo)
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W="$ROOT/build/engine"; mkdir -p "$W/src"
MIN=14.0
export RUSTUP_HOME="$W/rustup" CARGO_HOME="$W/cargo"
RUSTBIN="$(ls -d "$RUSTUP_HOME"/toolchains/*/bin | head -1)"
JOBS=$(sysctl -n hw.ncpu)

CLAMAV_VER=1.5.4;  CLAMAV_SHA=1af1117a228f1b5bc7fa91a0dabc37848a99e7d25188e9be8043332ce721dfd3
CLAMAV_URL=https://github.com/Cisco-Talos/clamav/releases/download/clamav-$CLAMAV_VER/clamav-$CLAMAV_VER.tar.gz
OPENSSL_VER=3.5.9; OPENSSL_SHA=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
OPENSSL_URL=https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VER/openssl-$OPENSSL_VER.tar.gz
PCRE_VER=10.49;    PCRE_SHA=53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384
PCRE_URL=https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE_VER/pcre2-$PCRE_VER.tar.bz2
JSONC_VER=0.19;    JSONC_SHA=37ad0249902e301bd9052bf712e511fcc6acff4ecaad4b5900aad9ce564e26de
JSONC_URL=https://s3.amazonaws.com/json-c_releases/releases/json-c-$JSONC_VER.tar.gz

fetch() { # url sha
  local f="$W/src/$(basename "$1")"
  [ -f "$f" ] || curl -fsSL -o "$f" "$1"
  [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$2" ] || { echo "HASH incorrecto: $f"; exit 1; }
  local d="${f%.tar.*}"; [ -d "$d" ] || tar -xf "$f" -C "$W/src"
}
fetch $CLAMAV_URL $CLAMAV_SHA; fetch $OPENSSL_URL $OPENSSL_SHA; fetch $PCRE_URL $PCRE_SHA; fetch $JSONC_URL $JSONC_SHA

build_arch() {
  local arch=$1 D="$W/deps-$1" B="$W/build-$1" O="$W/out-$1"
  local rtarget; [ "$arch" = arm64 ] && rtarget=aarch64-apple-darwin || rtarget=x86_64-apple-darwin
  mkdir -p "$D" "$B"
  if [ ! -f "$D/lib/libssl.a" ]; then
    echo "== [$arch] OpenSSL"; rm -rf "$B/openssl"; cp -R "$W/src/openssl-$OPENSSL_VER" "$B/openssl"; ( cd "$B/openssl"
      ./Configure darwin64-$([ $arch = arm64 ] && echo arm64 || echo x86_64)-cc no-shared no-tests no-docs --prefix="$D" --libdir=lib -mmacosx-version-min=$MIN >/dev/null
      make -j$JOBS >/dev/null && make install_sw >/dev/null ); fi
  if [ ! -f "$D/lib/libpcre2-8.a" ]; then
    echo "== [$arch] PCRE2"; cmake -S "$W/src/pcre2-$PCRE_VER" -B "$B/pcre2" -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES=$arch -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN -DCMAKE_INSTALL_PREFIX="$D" \
      -DBUILD_SHARED_LIBS=OFF -DPCRE2_BUILD_PCRE2GREP=OFF -DPCRE2_BUILD_TESTS=OFF -DPCRE2_SUPPORT_JIT=ON >/dev/null
    cmake --build "$B/pcre2" >/dev/null && cmake --install "$B/pcre2" >/dev/null; fi
  if [ ! -f "$D/lib/libjson-c.a" ]; then
    echo "== [$arch] json-c"; cmake -S "$W/src/json-c-$JSONC_VER" -B "$B/jsonc" -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES=$arch -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN -DCMAKE_INSTALL_PREFIX="$D" \
      -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_TESTING=OFF -DDISABLE_WERROR=ON >/dev/null
    cmake --build "$B/jsonc" >/dev/null && cmake --install "$B/jsonc" >/dev/null; fi
  echo "== [$arch] ClamAV"
  PATH="$RUSTBIN:$PATH" cmake -S "$W/src/clamav-$CLAMAV_VER" -B "$B/clamav" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=$arch -DCMAKE_OSX_DEPLOYMENT_TARGET=$MIN -DCMAKE_INSTALL_PREFIX="$O" \
    -DCMAKE_PREFIX_PATH="$D" -DOPENSSL_ROOT_DIR="$D" -DOPENSSL_USE_STATIC_LIBS=ON \
    -DRUST_COMPILER_TARGET=$rtarget -DENABLE_SHARED_LIB=OFF -DENABLE_STATIC_LIB=ON -DENABLE_JSON_SHARED=OFF \
    -DENABLE_TESTS=OFF -DENABLE_MAN_PAGES=OFF -DENABLE_EXAMPLES=OFF -DENABLE_UNRAR=ON -DENABLE_MILTER=OFF \
    -DENABLE_EXTERNAL_MSPACK=OFF -DDO_NOT_SET_RPATH=ON -DENABLE_SYSTEMD=OFF
  PATH="$RUSTBIN:$PATH" cmake --build "$B/clamav" -j$JOBS
  PATH="$RUSTBIN:$PATH" cmake --install "$B/clamav" >/dev/null
}

ARCHS=("${@:-arm64 x86_64}"); [ $# -eq 0 ] && ARCHS=(arm64 x86_64)
for a in "${ARCHS[@]}"; do build_arch "$a"; done

if [ ${#ARCHS[@]} -eq 2 ]; then
  U="$W/universal"; rm -rf "$U"; mkdir -p "$U"
  for b in clamscan clamdscan clamd freshclam sigtool; do
    lipo -create "$W/out-arm64/bin/$b" "$W/out-x86_64/bin/$b" -output "$U/$b" 2>/dev/null \
      || lipo -create "$W/out-arm64/sbin/$b" "$W/out-x86_64/sbin/$b" -output "$U/$b"
  done
  cp "$W/src/clamav-$CLAMAV_VER/COPYING.txt" "$U/LICENSE-ClamAV.txt" 2>/dev/null || cp "$W/src/clamav-$CLAMAV_VER/COPYING" "$U/LICENSE-ClamAV.txt"
  echo "$CLAMAV_VER" > "$U/VERSION"
  ls -la "$U"; for f in "$U"/clam* "$U"/freshclam "$U"/sigtool; do lipo -archs "$f"; otool -L "$f" | tail -n +2 | grep -v "^$f" | awk '{print "   "$1}' | sort -u | tr '\n' ' '; echo; done
fi
echo "OK"
