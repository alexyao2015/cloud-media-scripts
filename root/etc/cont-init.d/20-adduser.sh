#!/usr/bin/with-contenv sh

PUID=${PUID:-911}
PGID=${PGID:-911}

if [ ! "$(id -u abc)" -eq "$PUID" ]; then usermod -o -u "$PUID" abc ; fi
if [ ! "$(id -g abc)" -eq "$PGID" ]; then groupmod -o -g "$PGID" abc ; fi

. "/usr/bin/variables"

echo "
GID/UID
-------------------------------------
User uid:    $(id -u abc)
User gid:    $(id -g abc)
-------------------------------------
"
chmod -R 777 \
	/var/lock \
    $log_dir

chmod a+r /etc/fuse.conf

chown -R abc:abc \
    /tmp/rcloneconfig/ \
    /usr/bin/* \
    $read_decrypt_dir \
    $local_decrypt_dir \
    $local_media_dir
