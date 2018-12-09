####################
# BASE IMAGE
####################
FROM ubuntu:16.04

MAINTAINER prc2k10@googlemail.com <prc2k10@googlemail.com>


####################
# INSTALLATIONS
####################
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y \
        curl \
        cron \
        fuse \
        unionfs-fuse \
        bc \
        unzip \
        wget \
        ca-certificates && \
    update-ca-certificates && \
    apt-get install -y openssl && \
    sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

###################
# MergerFS
###################
RUN \
  wget https://github.com/trapexit/mergerfs/releases/download/2.25.0/mergerfs_2.25.0.ubuntu-xenial_amd64.deb && \
  dpkg -i mergerfs_2.25.0.ubuntu-xenial_amd64.deb && \
  rm mergerfs*.deb

# S6 overlay
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
ENV S6_KEEP_ENV=1

RUN \
    OVERLAY_VERSION=$(curl -sX GET "https://api.github.com/repos/just-containers/s6-overlay/releases/latest" | awk '/tag_name/{print $4;exit}' FS='[""]') && \
    curl -o /tmp/s6-overlay.tar.gz -L "https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" && \
    tar xfz  /tmp/s6-overlay.tar.gz -C /

####################
# ENVIRONMENT VARIABLES
####################
# Encryption
ENV ENCRYPT_MEDIA "1"
ENV READ_ONLY "1"

# Rclone
ENV BUFFER_SIZE "512M"
ENV CHECKERS "16"
ENV RCLONE_CLOUD_ENDPOINT "gd-crypt:"
ENV RCLONE_LOCAL_ENDPOINT "local-crypt:"
ENV RCLONE_VERBOSE "0"
ENV RCLONE_LOG_LEVEL "NOTICE"
ENV RCLONE_REMOTE_CONTROL "0"
ENV RCLONE_MOUNT_UMASK "0022"

# Rclone Mirror Settings
ENV MIRROR_MEDIA "0"
ENV RCLONE_MIRROR_ENDPOINT "gdm-crypt:"
ENV ENCRYPT_MIRROR_MEDIA "1"
ENV MIRROR_BWLIMIT "100M"
ENV MIRROR_TRANSFERS "4"
ENV MIRROR_TPS_LIMIT "1"
ENV MIRROR_TPS_LIMIT_BURST "1"

# Plexdrive
ENV CHUNK_SIZE "10M"
ENV CLEAR_CHUNK_MAX_SIZE ""
ENV CLEAR_CHUNK_AGE "24h"
ENV CHUNK_SIZE "10M"
ENV CHUNK_CHECK_THREADS "2"
ENV CHUNK_LOAD_THREADS "2"
ENV CHUNK_LOAD_AHEAD "3"
ENV MAX_CHUNKS "10"
ENV PLEXDRIVE_MOUNT_UMASK "0755"

# Union Mount
ENV UNION_ENABLED "1"
ENV UNION_PROGRAM "UNIONFS"
# or MERGERFS

# Time format
ENV DATE_FORMAT "+%F@%T"

# Local files removal
ENV REMOVE_LOCAL_FILES_BASED_ON "space"
ENV REMOVE_LOCAL_FILES_WHEN_SPACE_EXCEEDS_GB "100"
ENV FREEUP_ATLEAST_GB "80"
ENV REMOVE_LOCAL_FILES_AFTER_DAYS "30"

# Plex
ENV PLEX_URL ""
ENV PLEX_TOKEN ""

#cron
ENV CLOUDUPLOADTIME "0 7 * * *"
ENV RMDELETETIME "0 12 * * *"

####################
# SCRIPTS
####################
COPY setup/* /usr/bin/
COPY install.sh /
COPY scripts/* /usr/bin/
COPY root /


RUN chmod a+x /install.sh && \
    sh /install.sh && \
    chmod a+x /usr/bin/* && \
    groupmod -g 1000 users && \
	useradd -u 911 -U -d / -s /bin/false abc && \
	usermod -G users abc && \
    apt-get clean autoclean && \
    apt-get autoremove -y && \
    rm -rf /tmp/* /var/lib/{apt,dpkg,cache,log}/

####################
# VOLUMES
####################
# Define mountable directories.
#VOLUME /data/db /config /cloud-encrypt /cloud-decrypt /local-decrypt /local-media /chunks /log
VOLUME /config /cloud-encrypt /cloud-decrypt /local-decrypt /local-media /local-workdir /chunks /log

RUN chmod -R 777 /log

####################
# WORKING DIRECTORY
####################
WORKDIR /data

####################
# ENTRYPOINT
####################
ENTRYPOINT ["/init"]
CMD cron -f