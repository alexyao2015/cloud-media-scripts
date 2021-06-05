#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="fix-mnt-dir"

# Ensure media dir exists
mkdir -p "${FINAL_MOUNT_DIR}"

# Need to ensure that media isn't currently mounted before mounting
fusermount -uz "${FINAL_MOUNT_DIR}" > /dev/null 2>&1 || true
