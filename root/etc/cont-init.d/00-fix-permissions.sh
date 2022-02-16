#!/command/with-contenv sh
. "/usr/local/bin/logger"
program_name="fix-permissions"

echo "Setting permissions of /log..." | info "[${program_name}] "
chown -R nobody:nobody /log
chmod -R 755 /log
