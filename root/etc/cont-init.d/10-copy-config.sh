#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="copy-config"

echo "Copying config to /tmp/rcloneconfig..." | info "[${program_name}] "

cp -R /config/* /tmp/rcloneconfig/
