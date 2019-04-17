FROM alpine:latest

ENV RCLONE_VERSION="v1.46"
ENV RCLONE_RELEASE="rclone-${RCLONE_VERSION}-linux-amd64"
ENV RCLONE_ZIP="${RCLONE_RELEASE}.zip"
ENV RCLONE_URL="https://github.com/ncw/rclone/releases/download/${RCLONE_VERSION}/${RCLONE_ZIP}"

# dependencies
ENV DEPS \
    bash \
    bc \
    ca-certificates \
    coreutils \
    curl \
    findutils \
    fuse \
    openssl \
    procps \
    shadow \
    tzdata \
    unionfs-fuse \
    unzip \
    wget

RUN apk update \
    && apk add --no-cache $DEPS \
    && sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

###################
# MergerFS
###################
RUN apk add mergerfs --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ --allow-untrusted

# S6 overlay
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

RUN OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    curl -o /tmp/s6-overlay.tar.gz -L "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" && \
    tar xfz  /tmp/s6-overlay.tar.gz -C /

# Rclone
RUN cd /tmp \
    && wget "$RCLONE_URL" \
    && unzip "$RCLONE_ZIP" \
    && chmod a+x "${RCLONE_RELEASE}/rclone" \
    && cp -rf "${RCLONE_RELEASE}/rclone" "/usr/bin/rclone" \
    && rm -rf "$RCLONE_ZIP" \
    && rm -rf "$RCLONE_RELEASE"

RUN apk del \
    curl \
    unzip \
    wget

####################
# ENVIRONMENT VARIABLES
####################

# Rclone
ENV COPY_CHECKERS "4"
ENV COPY_TRANSFERS "4"
ENV COPY_DRIVE_CHUNK_SIZE "32M"
ENV RCLONE_CLOUD_ENDPOINT "direct-decrypt:"
ENV RCLONE_CACHE_ENDPOINT "cache-decrypt:"
ENV RCLONE_LOCAL_ENDPOINT "local-decrypt:"
ENV RCLONE_MASK "000"
ENV RCLONE_READ_TYPE "VFS"
#OR CACHE
ENV RCLONE_CACHE_READ_OPTIONS "--local-no-check-updated --buffer-size=0 --cache-chunk-size=5M --cache-info-age=28h --cache-read-retries=3 --cache-chunk-total-size=3G --cache-workers=10 --contimeout=5s --dir-cache-time=24h --max-read-ahead=128k --transfers=3 --tpslimit=8 --timeout=5s --track-renames -vv"
ENV RCLONE_VFS_READ_OPTIONS "--buffer-size=2048M --timeout=1h --tpslimit=1750 -vv"
ENV RCLONE_VFS_READ_OPTIONS_CACHING "--dir-cache-time=72h --poll-interval=60s --rc --rc-addr=:5572"

ENV RCLONE_PRECACHE "1"
ENV RCLONE_PRECACHE_DIR "/local-media"
ENV RCLONE_PRECACHE_METHOD ""
ENV RCLONE_VFS_PRECACHE_DIR ""
#or VFS or FIND
ENV RCLONE_READ_MANUAL_ENDPOINT ""

# Rclone Mirror Settings
ENV MIRROR_MEDIA "0"
ENV RCLONE_MIRROR_ENDPOINT "gdm-crypt:"
ENV ENCRYPT_MIRROR_MEDIA "1"
ENV MIRROR_BWLIMIT "100M"
ENV MIRROR_TRANSFERS "4"
ENV MIRROR_TPS_LIMIT "1"
ENV MIRROR_TPS_LIMIT_BURST "1"

# Time format
ENV DATE_FORMAT "+%F@%T"

# Local files removal
ENV REMOVE_LOCAL_FILES_BASED_ON "space"
ENV REMOVE_LOCAL_FILES_WHEN_SPACE_EXCEEDS_GB "100"
ENV FREEUP_ATLEAST_GB "80"
ENV REMOVE_LOCAL_FILES_AFTER_DAYS "30"

#Dedupe
ENV DEDUPE_ROOT "direct-decrypt:"
ENV DEDUPE_TPS_LIMIT "4"
ENV DEDUPE_TIME "0 6 * * *"
ENV DEDUPE_MODE "largest"

# Plex
ENV PLEX_URL ""
ENV PLEX_TOKEN ""

#cron
ENV CLOUDUPLOAD_TIME "30 1 * * *"
ENV RMDELETE_TIME "30 6 * * *"

# Union Mount MERGERFS OR UNIONFS
ENV UNION_PROGRAM "MERGERFS"
ENV MERGERFS_OPTIONS "splice_move,atomic_o_trunc,auto_cache,big_writes,default_permissions,direct_io,nonempty,allow_other,sync_read,category.create=ff,category.search=ff,minfreespace=0"

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
# Define mountable directories.
VOLUME /config /read-decrypt /cloud-decrypt /local-decrypt /local-media /local-media-edit /chunks /log

RUN chmod -R 777 /log

####################
# WORKING DIRECTORY
####################
WORKDIR /data

####################
# ENTRYPOINT
####################
ENTRYPOINT ["/init"]
