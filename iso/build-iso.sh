#!/bin/sh
# Builds the bootable installer ISO: dist/docs-vault-<version>-x86_64.iso
#   iso/build-iso.sh <version> [autoinstall.env]
# Needs: docker (with network access). Everything else runs in containers.
set -eu
cd "$(dirname "$0")/.."

VERSION=${1:-dev}
AUTOINSTALL=${2:-}
ALPINE_BRANCH=v3.24
ALPINE_VERSION=3.24.4
ALPINE_ISO=alpine-virt-$ALPINE_VERSION-x86_64.iso
ALPINE_SHA256=157d353f8e54252cad2d9812a0d56bb7fa2231fc154a110e1d180d7480ef8b4f
WG_IMAGE=lscr.io/linuxserver/wireguard:1.0.20260223-r0-ls130
VAULT_IMAGE=docs-vault:1

W=build/iso
# previous build output belongs to root (created in the container)
[ -d "$W" ] && docker run --rm -v "$PWD/build:/b" alpine:3.24 rm -rf /b/iso
mkdir -p "$W/payload/images" dist build/cache

echo "== docs-vault image"
docker build -q -t "$VAULT_IMAGE" -t "docs-vault:$VERSION" . >/dev/null
docker pull -q "$WG_IMAGE" >/dev/null
docker save "$VAULT_IMAGE" | gzip >"$W/payload/images/docs-vault.tar.gz"
echo "$VAULT_IMAGE" >"$W/payload/images/docs-vault.ref"
docker save "$WG_IMAGE" | gzip >"$W/payload/images/wireguard.tar.gz"
echo "$WG_IMAGE" >"$W/payload/images/wireguard.ref"
cp compose.yml README.md "$W/payload/"
cp -r wireguard-template "$W/payload/"
[ -n "$AUTOINSTALL" ] && cp "$AUTOINSTALL" "$W/payload/autoinstall.env"

echo "== Alpine $ALPINE_VERSION"
if [ ! -f "build/cache/$ALPINE_ISO" ]; then
	curl -fL -o "build/cache/$ALPINE_ISO.part" "https://dl-cdn.alpinelinux.org/alpine/$ALPINE_BRANCH/releases/x86_64/$ALPINE_ISO"
	mv "build/cache/$ALPINE_ISO.part" "build/cache/$ALPINE_ISO"
fi
echo "$ALPINE_SHA256  build/cache/$ALPINE_ISO" | sha256sum -c -
cp "build/cache/$ALPINE_ISO" "$W/alpine.iso"
cp -a iso/overlay "$W/overlay"

echo "== ISO"
docker run --rm -v "$PWD/$W:/work" -v "$PWD/iso/stage.sh:/stage.sh:ro" "alpine:${ALPINE_VERSION%.*}" sh /stage.sh
OUT="dist/docs-vault-$VERSION-x86_64.iso"
docker run --rm -v "$PWD:/w" alpine:3.24 chown -R "$(id -u):$(id -g)" /w/build/iso
mv "$W/out.iso" "$OUT"
(cd dist && sha256sum "$(basename "$OUT")" >"$(basename "$OUT").sha256")
echo "== done: $OUT ($(du -h "$OUT" | cut -f1))"
