FROM alpine:3.20
ARG TARGETARCH
ARG MC_RELEASE=RELEASE.2021-04-22T17-40-00Z
RUN apk add --no-cache ca-certificates curl && \
    curl -fsSL -o /usr/bin/mc \
      "https://github.com/minio/mc/releases/download/${MC_RELEASE}/mc.linux-${TARGETARCH}.${MC_RELEASE}" && \
    curl -fsSL -o /tmp/mc.sha256sum \
      "https://github.com/minio/mc/releases/download/${MC_RELEASE}/mc.linux-${TARGETARCH}.${MC_RELEASE}.sha256sum" && \
    echo "$(awk '{print $1}' /tmp/mc.sha256sum)  /usr/bin/mc" | sha256sum -c - && \
    rm /tmp/mc.sha256sum && \
    chmod +x /usr/bin/mc
ENTRYPOINT ["mc"]