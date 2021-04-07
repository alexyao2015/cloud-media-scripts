ARG MERGERFS_VERSION="2.32.1"
ARG RCLONE_VERSION="v1.53.3"

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
    && wget -O /tmp/s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64.tar.gz" \
    && mkdir -p /tmp/s6 \
    && tar zxvf /tmp/s6-overlay.tar.gz -C /tmp/s6 \
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
    && find . -type f -print0 | xargs -0 -n 1 -P 4 dos2unix

# ====================Begin Image===========================

FROM alpine:latest

RUN apk add --no-cache \
        bc \
        ca-certificates \
        fuse \
        openssl \
        shadow \
        tzdata \
    && sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

COPY --from=mergerfsbuilder /mergerfs/install/ /usr/local/
COPY --from=rclonedownloader /rclonedownloader/rclone /usr/bin
COPY --from=s6downloader /s6downloader /
COPY --from=rootfs-converter /rootfs /


####################
# ENVIRONMENT VARIABLES
####################

# Rclone; local-decrypt not used
ENV COPY_CHECKERS="4" \
    COPY_TRANSFERS="4" \
    COPY_DRIVE_CHUNK_SIZE="32M" \
    RCLONE_CLOUD_ENDPOINT="cloud:" \
    RCLONE_LOCAL_ENDPOINT="local-decrypt:" \
    RCLONE_PRECACHE="1" \
    RCLONE_FIND_PRECACHE_DIR="/local-media" \
    RCLONE_VFS_PRECACHE_DIR="" \
    RCLONE_PRECACHE_METHOD=""
#or VFS or FIND

# Rclone Mirror Settings, if backup mount set to 1 will use mirror endpoint
ENV MIRROR_MEDIA="0" \
    RCLONE_MIRROR_ENDPOINT="mirror:" \
    MIRROR_BWLIMIT="100M" \
    MIRROR_TRANSFERS="4" \
    MIRROR_TPS_LIMIT="8" \
    MIRROR_TPS_LIMIT_BURST="8" \
    RCLONE_BACKUP_MOUNT="0" \
    MIRROR_ENCRYPTED_ENDPOINT="mirror-copy-raw:" \
    CLOUD_ENCYPTED_ENDPOINT="mirror-copy-cloud-raw:" \
    MIRROR_SUBDIR="Sync"

# Time format
ENV DATE_FORMAT="+%F@%T" \
    TZ="America/Chicago"

# Local files removal rmlocal
ENV REMOVE_LOCAL_FILES_BASED_ON="space" \
    REMOVE_LOCAL_FILES_WHEN_SPACE_EXCEEDS_GB="100" \
    REMOVE_LOCAL_FILES_AFTER_DAYS="30"


####################
# SCRIPTS
####################

RUN chmod a+x /usr/bin/* && \
    groupmod -g 1000 users && \
	useradd -u 911 -U -d / -s /bin/false abc && \
	usermod -G users abc

RUN mkdir -p \
        /mounts/local-decrypt \
        /mounts/cloud-decrypt \
        /data/media \
        /config \
        /log \
        /tmp/rcloneconfig \
    && chmod 755 \
        /mounts \
        /data \
        /config \
        /log \
        /tmp/rcloneconfig \
    && chown abc:abc \
        /mounts \
        /data \
        /config \
        /tmp/rcloneconfig

# System Vars
ENV \
    S6_FIX_ATTRS_HIDDEN=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    MERGERFS_OPTIONS="splice_move,atomic_o_trunc,auto_cache,big_writes,default_permissions,direct_io,nonempty,allow_other,sync_read,category.create=ff,category.search=ff,minfreespace=0" \
    RCLONE_VFS_READ_OPTIONS="--buffer-size=128M --dir-cache-time=72h --poll-interval=60s --rc --rc-addr=:5572 --timeout=1h --tpslimit=1750 -vv" \
    RCLONE_MASK="000" \
    MAX_LOG_SIZE_BYTES=1000000 \
    MAX_LOG_NUMBER=10

# User Vars
ENV \
    RCLONE_LOCAL_DECRYPT_REMOTE="local-decrypt" \
    RCLONE_LOCAL_DECRYPT_DIR="/mnt/local-decrypt" \
    RCLONE_CLOUD_DECRYPT_REMOTE="cloud" \
    RCLONE_CLOUD_DECRYPT_DIR="" \
    RCLONE_MIRROR_REMOTE="mirror" \
    RCLONE_MIRROR_DIR="" \
    DEDUPE_CLOUD_DECRYPT="1" \
    DEDUPE_MIRROR_REMOTE="0" \
    DEDUPE_SETTINGS="--dedupe-mode largest --tpslimit 4 -v" \
    CRON_CLOUDUPLOAD_TIME="30 1 * * *" \
    CRON_RMDELETE_TIME="30 6 * * *" \
    CRON_DEDUPE_TIME="0 6 * * *" \
    CRON_MIRROR_TIME="0 6 * * *" \
    CRON_EMPTY_TRASH_TIME="0 0 31 2 0" \
    PRECACHE_ENABLED=1 \
    PRECACHE_VFS_DIR="" \
    PRECACHE_FIND_DIR="/mounts/cloud-decrypt" \
    PRECACHE_USE_RC=1

# Plex
ENV PLEX_URL="" \
    PLEX_TOKEN=""
# Temporary Config
ENV \
    RCLONE_USE_MIRROR_AS_CLOUD_REMOTE="0"

CMD ["/init"]
