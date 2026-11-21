#!/bin/sh
# Starts dufs (file server, localhost only) and nginx (access rules + UI) in one container.
set -eu

: "${VAULT_USER:?set VAULT_USER (editor login)}"
: "${VAULT_PASS:?set VAULT_PASS (editor password)}"
case "$VAULT_USER" in *[@:,\|[:space:]]*) echo "VAULT_USER must not contain @ : , | or spaces" >&2; exit 1;; esac
case "$VAULT_PASS" in *[@,\|[:space:]]*)  echo "VAULT_PASS must not contain @ , | or spaces" >&2; exit 1;; esac
PUID="${PUID:-1000}"
PGID="${PGID:-100}"

# HMAC key for "folder unlocked" cookies; kept in /state so unlocks survive restarts
mkdir -p /state
if [ ! -s /state/secret ]; then
    (umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > /state/secret)
    echo "docs-vault: generated /state/secret"
fi
chown root:nginx /state/secret
chmod 640 /state/secret

# reverse proxies allowed to set X-Forwarded-For (e.g. "172.16.0.0/12 192.168.1.10")
: > /etc/nginx/vault/realip.conf
for net in ${VAULT_TRUSTED_PROXIES:-}; do
    echo "set_real_ip_from $net;" >> /etc/nginx/vault/realip.conf
done
[ -s /etc/nginx/vault/realip.conf ] && echo "real_ip_header X-Forwarded-For;" >> /etc/nginx/vault/realip.conf

su-exec "$PUID:$PGID" dufs /data --bind 127.0.0.1 --port 5000 \
    --allow-upload --allow-delete --allow-search --allow-archive \
    --assets /assets \
    --auth "$VAULT_USER:$VAULT_PASS@/:rw" --auth "@/" &
DUFS=$!
nginx -g 'daemon off;' &
NGINX=$!

STOP=0
trap 'STOP=1; kill -TERM $DUFS $NGINX 2>/dev/null' TERM INT
# if either process exits, stop the other one too (docker restarts the container)
while kill -0 $DUFS 2>/dev/null && kill -0 $NGINX 2>/dev/null; do sleep 2; done
kill -TERM $DUFS $NGINX 2>/dev/null || true
wait || true
[ "$STOP" = 1 ] && exit 0
echo "docs-vault: a process exited unexpectedly" >&2
exit 1
