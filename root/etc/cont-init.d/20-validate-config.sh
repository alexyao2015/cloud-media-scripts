#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="validate-config"
check_failed=0

if [[ ! -f /tmp/rcloneconfig/rclone.conf ]]; then

  echo "rclone.conf does not exist at /config/rclone.conf!" | error "[${program_name}] "
  echo "create a rclone.conf and place it at /config/rclone.conf" | error "[${program_name}] "
  check_failed=1
else

  if [ "$(df -P -T | grep /mounts/local-decrypt | awk '{print $7}')" != "/mounts/local-decrypt" ]; then

    if ! rclone --config=/tmp/rcloneconfig/rclone.conf listremotes | grep -q "^${RCLONE_LOCAL_DECRYPT_REMOTE}:$"; then
      echo "Could not find local-decrypt remote in rclone.conf at /config/rclone.conf!" | error "[${program_name}] "
      echo "Add a local-decrypt remote named \"${RCLONE_LOCAL_DECRYPT_REMOTE}\" or modify the" | error "[${program_name}] "
      echo "RCLONE_LOCAL_DECRYPT_REMOTE environment variable to the correct remote" | error "[${program_name}] "
      echo "Alternatively directly bindmount /mounts/local-decrypt" | error "[${program_name}] "
      check_failed=1
    fi
  else

    echo "Bind mount detected at /mounts/local-decrypt" | info "[${program_name}] "
    echo "Disabling local-decrypt mount..." | info "[${program_name}] "
    echo -n "0" > /var/run/s6/container_environment/RCLONE_MOUNT_LOCAL_DECRYPT

  fi

  if ! rclone --config=/tmp/rcloneconfig/rclone.conf listremotes | grep -q "^${RCLONE_CLOUD_DECRYPT_REMOTE}:$"; then
    echo "Could not find local-decrypt remote in rclone.conf at /config/rclone.conf!" | error "[${program_name}] "
    echo "Add a cloud-decrypt remote named \"${RCLONE_CLOUD_DECRYPT_REMOTE}\" or modify the" | error "[${program_name}] "
    echo "RCLONE_CLOUD_DECRYPT_REMOTE environment variable to the correct remote" | error "[${program_name}] "
    check_failed=1
  fi

fi

if [ "${check_failed}" -eq "1" ]; then
  echo "Configuration errors were detected! To run rclone config, start with interactive \"-it\"" | error "[${program_name}] "
  echo "mode with CONTAINER_START_RCLONE_CONFIG=1" | error "[${program_name}] "
  echo 'docker run -it -v ${PWD}/scripts-data/config:/config -v ${PWD}/scripts-data/log:/log' | error "[${program_name}] "
  echo '-e CONTAINER_START_RCLONE_CONFIG=1 ghcr.io/alexyao2015/cloud-media-scripts' | error "[${program_name}] "
  exit 1
fi

#check_rclone_mirror() {
#  if [ "$(printenv MIRROR_MEDIA)" != "0" ]; then
#    if [[ ! "$(printenv RCLONE_MIRROR_ENDPOINT)" == *: ]]; then
#      printf "\n\n"
#      echo "Missing colon (:) in RCLONE_MIRROR_ENDPOINT ($(printenv RCLONE_MIRROR_ENDPOINT))"
#      echo "Run: docker exec -ti <DOCKER_CONTAINER> rclone_setup"
#      printf "\n\n"
#
#      exit 02
#    fi
#
#    if [ "$(rclone listremotes $rclone_config | grep $(printenv RCLONE_MIRROR_ENDPOINT) | wc -l)" == "0" ]; then
#      printf "\n\n"
#      echo "RCLONE_MIRROR_ENDPOINT ($(printenv RCLONE_MIRROR_ENDPOINT)) endpoint has not been created within rclone"
#      echo "Run: docker exec -ti <DOCKER_CONTAINER> rclone_setup"
#      printf "\n\n"
#
#      exit 02
#    fi
#  fi
#}
