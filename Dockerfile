ARG MERGERFS_VERSION="2.33.3"
ARG RCLONE_VERSION="v1.57.0"

###################
# MergerFS
###################
FROM alpine:latest as mergerfsbuilder
ARG MERGERFS_VERSION
WORKDIR /mergerfs

RUN apk add --no-cache \
        g++ \
        linux-headers \
        make

RUN wget "https://github.com/trapexit/mergerfs/releases/download/${MERGERFS_VERSION}/mergerfs-${MERGERFS_VERSION}.tar.gz" \
    && tar -xzf "mergerfs-${MERGERFS_VERSION}.tar.gz" \
    && cd "mergerfs-${MERGERFS_VERSION}" \
    && make STATIC=1 LTO=1 PREFIX="/install" DESTDIR="/mergerfs" install

###################
# Rclone
###################
FROM alpine:latest as rclonedownloader
ARG RCLONE_VERSION
WORKDIR /rclonedownloader

ENV RCLONE_URL="https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip"

RUN wget --no-check-certificate -O rclone.zip \
        "https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-amd64.zip" \
    && unzip rclone.zip \
    && mv rclone-*/rclone rclone \
    && chmod 755 rclone

###################
# S6 Overlay
###################
FROM alpine:latest as s6downloader
WORKDIR /s6downloader

RUN set -x \
    && S6_OVERLAY_VERSION=$(wget --no-check-certificate -qO - https://api.github.com/repos/just-containers/s6-overlay/releases/latest | awk '/tag_name/{print $4;exit}' FS='[""]') \
    && S6_OVERLAY_VERSION=${S6_OVERLAY_VERSION:1} \
    && wget -O /tmp/s6-overlay-arch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64-${S6_OVERLAY_VERSION}.tar.xz" \
    && wget -O /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch-${S6_OVERLAY_VERSION}.tar.xz" \
    && mkdir -p /tmp/s6 \
    && tar -Jxvf /tmp/s6-overlay-noarch.tar.xz -C /tmp/s6 \
    && tar -Jxvf /tmp/s6-overlay-arch.tar.xz -C /tmp/s6 \
    && cp -r /tmp/s6/* .

###################
# Rootfs Converter
###################
FROM alpine:latest as rootfs-converter
WORKDIR /rootfs

RUN set -x \
    && apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
        dos2unix

COPY root .
RUN set -x \
    && find . -type f -print0 | xargs -0 -n 1 -P 4 dos2unix \
    && chmod -R +x *

# ====================Begin Image===========================

FROM alpine:latest

RUN apk add --no-cache \
        curl \
        fuse \
        shadow \
        tzdata

RUN sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

RUN mkdir -p \
        /mounts/local-decrypt \
        /mounts/cloud-decrypt \
        /data/mnt \
        /config \
        /log \
        /scratch \
    && chmod 755 \
        /mounts \
        /data \
        /config \
        /log \
        /scratch \
    && chown nobody:nobody \
        /log

COPY --from=rclonedownloader /rclonedownloader/rclone /usr/bin
COPY --from=mergerfsbuilder /mergerfs/install/bin /bin
COPY --from=s6downloader /s6downloader /
COPY --from=rootfs-converter /rootfs /

# System Vars
ENV \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    MERGERFS_OPTIONS="nonempty,allow_other,async_read=true,cache.files=partial,dropcacheonclose=true,category.create=ff,category.search=ff,minfreespace=0" \
    RCLONE_MASK="000" \
    MAX_LOG_SIZE_BYTES=1000000 \
    MAX_LOG_NUMBER=10 \
    RCLONE_MOUNT_LOCAL_DECRYPT=1

#############
# User Vars
#############
# Timezone
ENV \
    TZ="America/Chicago"

# Rclone mount config
ENV \
    RCLONE_VFS_READ_OPTIONS="--cache-dir=/scratch --dir-cache-time=72h --fast-list --poll-interval=24h --rc --rc-addr=:5572 --timeout=1h --tpslimit=1750 --vfs-cache-max-age=12h --vfs-cache-max-size=20G --vfs-cache-mode=full --vfs-cache-poll-interval=1h --vfs-read-ahead=128M --vfs-read-chunk-size-limit=512M --vfs-read-chunk-size=64M -vv" \
    RCLONE_LOCAL_DECRYPT_REMOTE="local-decrypt" \
    RCLONE_LOCAL_DECRYPT_DIR="/mnt/local-decrypt" \
    RCLONE_CLOUD_DECRYPT_REMOTE="cloud" \
    RCLONE_CLOUD_DECRYPT_DIR="" \
    RCLONE_MIRROR_DECRYPT_REMOTE="mirror" \
    RCLONE_MIRROR_DECRYPT_DIR=""

# Precache Config
ENV \
    PRECACHE_ENABLED=1 \
    PRECACHE_VFS_DIR="" \
    PRECACHE_FIND_DIR="/mounts/cloud-decrypt" \
    PRECACHE_USE_RC=1

# Dedupe Config
ENV \
    DEDUPE_OPTIONS="--dedupe-mode largest --fast-list --tpslimit 4 -v" \
    CRON_DEDUPE_TIME="0 6 * * *" \
    DEDUPE_CLOUD_DECRYPT=1 \
    DEDUPE_MIRROR_REMOTE=1

# Rmlocal Config
# RCLONE_SCRIPT_OPTIONS applies to cloudupload and rmlocal
ENV \
    RCLONE_SCRIPT_OPTIONS="--drive-chunk-size 32M --checkers 4 --fast-list --transfers 4 -v" \
    CRON_RMDELETE_TIME="30 4 * * *" \
    RMLOCAL_MAX_SIZE_GB="100" \
    CLOUD_UPLOAD_AFTER_RMLOCAL=1

# Cloudupload config
# Only used when rmlocal is not used because CLOUD_UPLOAD_AFTER_RMLOCAL
ENV \
    CRON_CLOUDUPLOAD_TIME="0 0 31 2 0"

# Mirror from cloud -> mirror
ENV \
    MIRROR_OPTIONS="--transfers 4 --bwlimit 100M --fast-list --tpslimit 8 --tpslimit-burst 8 --drive-server-side-across-configs -v" \
    CRON_MIRROR_TIME="0 6 * * *" \
    MIRROR_ENCRYPTED_ENDPOINT="mirror-copy-raw" \
    CLOUD_ENCYPTED_ENDPOINT="cloud-raw" \
    MIRROR_SUBDIR="Sync" \
    MIRROR_VALIDATE_CONFIG=1

# Plex
ENV \
    CRON_EMPTY_TRASH_TIME="0 0 31 2 0" \
    PLEX_URL="" \
    PLEX_TOKEN=""

# Temporary Config
ENV \
    RCLONE_USE_MIRROR_AS_CLOUD_REMOTE=0 \
    CONTAINER_START_RCLONE_CONFIG=0

ENTRYPOINT ["/init"]
