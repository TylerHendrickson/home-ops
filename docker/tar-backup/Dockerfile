# syntax=docker/dockerfile:1

# IMAGE_VERSION is *our* version for this image (Dockerfile + backup.sh), bumped
# by hand when either changes meaningfully. It is not an upstream dependency, so
# it intentionally has no Renovate pragma; the build pipeline publishes the image
# under this tag.
ARG IMAGE_VERSION=0.2.1

###############################################################################
# Stage 1 — rclone
###############################################################################
FROM rclone/rclone:1.74.4@sha256:c61954aaa32328a5486715dd063a81c7879f5195ad3505cd362deddd509dc4a1 AS rclone

###############################################################################
# Stage 2 — supercronic
#   When bumping SUPERCRONIC_VERSION, refresh BOTH sha1 values below from
#   the matching release page: https://github.com/aptible/supercronic/releases
###############################################################################
FROM debian:bookworm-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df AS fetch
# renovate: datasource=github-releases depName=aptible/supercronic
ARG SUPERCRONIC_VERSION=v0.2.47
ARG TARGETARCH
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) SUPERCRONIC_SHA1=712d2ece75da6f6e530192a151488578153e4e96 ;; \
        arm64) SUPERCRONIC_SHA1=93323899ddca3f1198f1796a4bf4418ed1e7982e ;; \
        *) echo "ERROR: unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates; \
    SC="supercronic-linux-${TARGETARCH}"; \
    curl -fsSLO "https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/${SC}"; \
    echo "${SUPERCRONIC_SHA1}  ${SC}" | sha1sum -c -; \
    install -m 0755 "${SC}" /usr/local/bin/supercronic

###############################################################################
# Final image. Slim base provides GNU tar/gzip/coreutils/util-linux(flock).
###############################################################################
FROM debian:bookworm-slim@sha256:60eac759739651111db372c07be67863818726f754804b8707c90979bda511df

# Include an HTTP client ONLY if you intend to use external heartbeat pings
# (PING_URL). Off by default to keep the image lean and apt-free.
ARG INCLUDE_HTTP_CLIENT=false
RUN set -eux; \
    if [ "${INCLUDE_HTTP_CLIENT}" = "true" ]; then \
        apt-get update; \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl; \
        rm -rf /var/lib/apt/lists/*; \
    fi

COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone
COPY --from=fetch  /usr/local/bin/supercronic /usr/local/bin/supercronic
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod 0755 /usr/local/bin/rclone /usr/local/bin/supercronic /usr/local/bin/backup.sh \
 && mkdir -p /etc/backup

EXPOSE 9746
ENTRYPOINT ["/usr/local/bin/supercronic", "-prometheus-listen-address", "0.0.0.0:9746", "/etc/backup/crontab"]
