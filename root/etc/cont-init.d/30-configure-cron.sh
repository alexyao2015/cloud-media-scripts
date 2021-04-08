#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="configure-cron"

echo "Configuring cron scripts..." | info "[${program_name}] "

echo "${CRON_RMDELETE_TIME} /bin/s6-svc -o /var/run/s6/services/script-rmlocal
${CRON_DEDUPE_TIME} /bin/s6-svc -o /var/run/s6/services/script-dedupe
${CRON_MIRROR_TIME} /bin/s6-svc -o /var/run/s6/services/script-mirror
${CRON_EMPTY_TRASH_TIME} /bin/s6-svc -o /var/run/s6/services/script-emptytrash" > /etc/crontabs/root
