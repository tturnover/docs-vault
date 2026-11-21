# Documentation vault: dufs file server + nginx (njs) for anonymous read, editor login,
# hidden and password-protected folders. One container, port 80.
ARG DUFS_VERSION=v0.47.0
FROM sigoden/dufs:${DUFS_VERSION} AS dufs

FROM nginx:1.31.9-alpine
RUN apk add --no-cache su-exec
COPY --from=dufs /bin/dufs /usr/local/bin/dufs
COPY nginx/nginx.conf   /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY nginx/vault.js     /etc/nginx/vault/vault.js
COPY nginx/401.html     /usr/share/nginx/html/__login401.html
COPY nginx/404.html     /usr/share/nginx/html/__notfound.html
COPY assets/            /assets/
COPY entrypoint.sh      /entrypoint.sh
RUN touch /etc/nginx/vault/realip.conf && nginx -t

ENV PUID=1000 PGID=100
VOLUME ["/data", "/state"]
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s CMD wget -q -O /dev/null http://127.0.0.1/__dufs__/health || exit 1
ENTRYPOINT ["/entrypoint.sh"]
