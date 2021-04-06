#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="reconfigure-user"

PUID=${PUID:-911}
PGID=${PGID:-911}

echo "Reconfiguring GID and UID" | info "[${program_name}] "
groupmod -o -g "$PGID" abc
usermod -o -u "$PUID" abc

echo "User uid:    $(id -u abc)" | info "[${program_name}] "
echo "User gid:    $(id -g abc)" | info "[${program_name}] "

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
