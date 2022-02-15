#!/command/with-contenv sh
. "/usr/local/bin/logger"
program_name="configure-cron"

echo "Configuring cron scripts..." | info "[${program_name}] "

echo "${CRON_CLOUDUPLOAD_TIME} s6-svc -o /run/service/script-cloudupload
${CRON_RMDELETE_TIME} s6-svc -o /run/service/script-rmlocal
${CRON_DEDUPE_TIME} s6-svc -o /run/service/script-dedupe
${CRON_MIRROR_TIME} s6-svc -o /run/service/script-mirror
${CRON_EMPTY_TRASH_TIME} s6-svc -o /run/service/script-emptytrash" > /etc/crontabs/root
