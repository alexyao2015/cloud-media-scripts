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
    && make PREFIX="/install" DESTDIR="/mergerfs" install 

###################
# Rclone
###################
FROM busybox:latest as rclonedownloader
ARG RCLONE_VERSION
WORKDIR /rclonedownloader

ENV RCLONE_RELEASE="rclone-${RCLONE_VERSION}-linux-amd64"
ENV RCLONE_ZIP="${RCLONE_RELEASE}.zip"
ENV RCLONE_URL="https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/${RCLONE_ZIP}"

RUN wget --no-check-certificate "$RCLONE_URL" \
    && unzip "$RCLONE_ZIP" \
    && mv "${RCLONE_RELEASE}/rclone" rclone \
    && chown root:root rclone \
    && chmod 755 rclone

FROM busybox:latest as s6downloader
WORKDIR /s6downloader

RUN OVERLAY_VERSION=$(wget --no-check-certificate -qO - https://api.github.com/repos/just-containers/s6-overlay/releases/latest | awk '/tag_name/{print $4;exit}' FS='[""]') \
    && wget -O s6-overlay.tar.gz "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" \
    && tar xfz s6-overlay.tar.gz \
    && rm s6-overlay.tar.gz

# ====================Begin Image===========================

FROM alpine:latest

RUN apk add --no-cache \
        bash \
        bc \
        ca-certificates \
        coreutils \
        findutils \
        fuse \
        libgcc \
        libstdc++ \ 
        openssl \
        procps \
        shadow \
        tzdata \
    && sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

COPY --from=mergerfsbuilder /mergerfs/install/ /usr/local/
COPY --from=rclonedownloader /rclonedownloader/rclone /usr/bin
COPY --from=s6downloader /s6downloader /

# S6 overlay
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

####################
# ENVIRONMENT VARIABLES
####################

# Rclone; local-decrypt not used
ENV COPY_CHECKERS="4" \
    COPY_TRANSFERS="4" \
    COPY_DRIVE_CHUNK_SIZE="32M" \
    RCLONE_CLOUD_ENDPOINT="cloud:" \
    RCLONE_LOCAL_ENDPOINT="local-decrypt:" \
    RCLONE_MASK="000" \
    RCLONE_VFS_READ_OPTIONS="--buffer-size=128M --dir-cache-time=72h --poll-interval=60s --rc --rc-addr=:5572 --timeout=1h --tpslimit=1750 -vv" \
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

#Dedupe
ENV DEDUPE_ROOT="cloud:" \
    DEDUPE_MIRROR_ROOT="" \
    DEDUPE_TPS_LIMIT="4" \
    DEDUPE_MODE="largest"

# Plex
ENV PLEX_URL="" \
    PLEX_TOKEN=""

#Cron
ENV CLOUDUPLOAD_TIME="30 1 * * *" \
    RMDELETE_TIME="30 6 * * *" \
    DEDUPE_TIME="0 6 * * *" \
    MIRROR_TIME="0 6 * * *"

####################
# SCRIPTS
####################
COPY setup/* /usr/bin/
COPY scripts/* /usr/bin/
COPY root /

RUN chmod a+x /usr/bin/* && \
    groupmod -g 1000 users && \
	useradd -u 911 -U -d / -s /bin/false abc && \
	usermod -G users abc && \
    rm -rf /tmp/*

####################
# VOLUMES
####################
# Label mountable directories.
# VOLUME /config /read-decrypt /local-decrypt /local-media /log

RUN mkdir -p \
    /mounts/local-decrypt \
    /mounts/cloud-decrypt \
    /mounts/media

# System Vars
ENV \
    MERGERFS_OPTIONS="splice_move,atomic_o_trunc,auto_cache,big_writes,default_permissions,direct_io,nonempty,allow_other,sync_read,category.create=ff,category.search=ff,minfreespace=0"


# User Vars
ENV \
    RCLONE_LOCAL_DECRYPT_REMOTE="local-decrypt" \
    RCLONE_LOCAL_DECRYPT_DIR="mnt/local-decrypt" \
    RCLONE_CLOUD_DECRYPT_REMOTE="cloud" \
    RCLONE_CLOUD_DECRYPT_DIR="" \
    RCLONE_MIRROR_REMOTE="mirror" \
    RCLONE_MIRROR_DIR="" \

# Temporary Config
ENV \
    RCLONE_USE_MIRROR_AS_CLOUD_REMOTE="0"

####################
# WORKING DIRECTORY
####################
WORKDIR /data

####################
# CMD
####################
CMD ["/init"]
