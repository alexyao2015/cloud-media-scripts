#!/command/with-contenv sh
. "/usr/local/bin/logger"
program_name="copy-config"

if [ "${CONTAINER_START_RCLONE_CONFIG}" -eq "1" ]; then
  echo "Rclone config variable enabled using CONTAINER_START_RCLONE_CONFIG=1!" | info "[${program_name}] "
  echo "Ensure started with \"-it\" if not working" | info "[${program_name}] "
  rclone --config=/config/rclone.conf config
  echo "Rclone config complete! Restart container and be sure to set CONTAINER_START_RCLONE_CONFIG=0" | info "[${program_name}] "
  echo "on the next run!" | info "[${program_name}] "
  exit 1
fi
