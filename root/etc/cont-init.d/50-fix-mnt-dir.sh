#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="fix-mnt-dir"

# Need to ensure that media isn't currently mounted before mounting
fusermount -uz /data/mnt > /dev/null 2>&1

# Ensure media dir exists
mkdir -p /data/mnt
