#!/usr/bin/with-contenv sh

echo "Copying config to /tmp/rcloneconfig..."
cp -R /config/* /tmp/rcloneconfig/

echo "${cloud_upload_time} /bin/s6-svc -o /var/run/s6/services/script-cloudupload" >> /etc/crontabs/root
echo "${rm_delete_time} /bin/s6-svc -o /var/run/s6/services/script-rmlocal" >> /etc/crontabs/root
echo "${dedupe_time} /bin/s6-svc -o /var/run/s6/services/script-dedupe" >> /etc/crontabs/root
echo "${mirror_time} /bin/s6-svc -o /var/run/s6/services/script-mirror" >> /etc/crontabs/root
echo "${emptytrash_time} /bin/s6-svc -o /var/run/s6/services/script-emptytrash" >> /etc/crontabs/root
