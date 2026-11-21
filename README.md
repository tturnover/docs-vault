# docs-vault

Documentation vault: one container with [dufs](https://github.com/sigoden/dufs) (files) and nginx + njs
(UI, login, hidden / password-protected folders), plus an optional WireGuard VPN container.
Ukrainian web UI: view PDFs, videos, Office/OpenDocument files, STL models, Markdown; upload by drag & drop or paste;
edit text files in the browser.

Three ways to run it:

1. **Appliance ISO** (Releases): boot it on a VM or PC, answer a few questions, done.
2. **Docker Compose** with the prebuilt image tarball (Releases) or `--build`.
3. Build everything yourself: `docker build` / `iso/build-iso.sh`.

## Appliance ISO

`docs-vault-<version>-x86_64.iso` is an Alpine Linux 3.24 installer (BIOS and UEFI, works on a VM or a PC
with common hardware; `linux-virt` kernel). Boot it, press Enter, and answer:
disk (**erased**), hostname, time zone, root password, editor login/password, web port, VPN on/off,
VPN public name, port and client names.

After the reboot the console shows the web address. On the appliance:

| | |
|---|---|
| settings | `/opt/docs-vault/.env`, then `rc-service docs-vault restart` |
| documents | `/srv/vault/data` |
| VPN client (QR code + config) | `vault-peer <name>` |
| updates | `apk update && apk upgrade` |

Write it to a USB stick with `dd if=docs-vault-….iso of=/dev/sdX bs=4M` (or balenaEtcher / Rufus in DD mode).

Unattended install: add `docs-vault/autoinstall.env` to the ISO (see the header of
`iso/overlay/usr/local/bin/dv-install`), or build with `iso/build-iso.sh <version> answers.env`.

## What's inside

| Path | Purpose |
|---|---|
| `Dockerfile` | builds `docs-vault:1` (nginx 1.31.9-alpine + dufs v0.47.0) |
| `entrypoint.sh` | starts dufs on 127.0.0.1:5000 and nginx on :80, creates `/state/secret` |
| `nginx/default.conf` | access model: anonymous read, editor via `docs_auth` cookie + Basic login |
| `nginx/vault.js` | hidden / password folders (marker file `.vault` inside a folder) |
| `assets/` | web UI (`index.html`) and pdf.js |
| `compose.yml` | `vault` + `wireguard` services |
| `wireguard-template/server.conf` | VPN firewall: clients may reach only the vault web UI |
| `iso/` | appliance ISO: `build-iso.sh` (host, needs docker), `stage.sh` (in container), live overlay + installer |

Volumes: `/data` = the documents, `/state` = HMAC key for "folder unlocked" cookies.

## Docker Compose

```sh
cp .env.example .env        # set VAULT_USER / VAULT_PASS / VAULT_DATA / WG_HOST …
docker compose --env-file .env up -d --build
# or, without building: docker load < docs-vault-<version>-image.tar.gz ; docker compose --env-file .env up -d
```

- Web UI: `http://<host>:${VAULT_PORT}/` (put Caddy / another reverse proxy in front for https).
- Editor password rules: no `@ , |` or spaces (dufs rule syntax); login also no `:`.
- Behind a reverse proxy (Caddy, nginx…) set `VAULT_TRUSTED_PROXIES` to its address so the
  password rate limit sees real client addresses.
- VPN is enabled by `COMPOSE_PROFILES=vpn`; remove that line for web only.

## VPN (WireGuard)

- Forward **UDP `${WG_PORT}`** on the router to this host.
- `WG_PEERS=phone,laptop` creates one client per name. Client files appear in
  `wireguard/peer_<name>/`: `peer_<name>.conf` (import into the WireGuard app) and `peer_<name>.png` (QR code for phones).
  These contain private keys — hand them over privately.
- Connected clients open **http://vault.vpn/** (or http://10.213.77.10/). Only the vault is routed through the tunnel;
  the rest of the client's traffic goes as usual.
- Add a client later: append its name to `WG_PEERS`, then `docker compose up -d wireguard`.
- Remove a client: drop its name from `WG_PEERS`, `docker compose up -d wireguard`.

## Folder access

The editor sets it per folder with the shield button: **Для всіх / Прихована / З паролем**.
It is stored as `.vault` inside the folder (moves with the folder):

```json
{"hidden": true}
{"salt": "<hex>", "hash": "<sha256(salt + password)>"}
```

Readers: hidden folders return 404 everywhere (listing, search, ZIP, direct links); password folders need
the password once per device (cookie, 30 days); a ZIP of a folder containing protected content is refused.
The editor sees everything.

## Building

```sh
docker build -t docs-vault:1 .          # container image
iso/build-iso.sh 1.0.0                   # → dist/docs-vault-1.0.0-x86_64.iso (needs docker + network)
```

## License

MIT, see `LICENSE`. Bundled third-party components: `THIRD_PARTY_NOTICES.md`.
