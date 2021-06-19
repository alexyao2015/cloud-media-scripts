#!/usr/bin/with-contenv sh
. "/usr/local/bin/logger"
program_name="validate-config"
check_failed=0

if [[ ! -f /config/rclone.conf ]]; then

  echo "rclone.conf does not exist at /config/rclone.conf!" | error "[${program_name}] "
  echo "create a rclone.conf and place it at /config/rclone.conf" | error "[${program_name}] "
  check_failed=1
else

  if [ "$(df -P -T | grep /mounts/local-decrypt | awk '{print $7}')" != "/mounts/local-decrypt" ]; then

    if ! rclone --config=/config/rclone.conf listremotes | grep -q "^${RCLONE_LOCAL_DECRYPT_REMOTE}:$"; then
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

  # Only check mirror decrypt if enabled
  if [ "${RCLONE_USE_MIRROR_AS_CLOUD_REMOTE}" -eq 1 ]; then
    if ! rclone --config=/config/rclone.conf listremotes | grep -q "^${RCLONE_MIRROR_DECRYPT_REMOTE}:$"; then
      echo "Could not find mirror-decrypt remote in rclone.conf at /config/rclone.conf!" | error "[${program_name}] "
      echo "Add a mirror-decrypt remote named \"${RCLONE_MIRROR_DECRYPT_REMOTE}\" or modify the" | error "[${program_name}] "
      echo "RCLONE_MIRROR_DECRYPT_REMOTE environment variable to the correct remote" | error "[${program_name}] "
      check_failed=1
    fi
  else
    if ! rclone --config=/config/rclone.conf listremotes | grep -q "^${RCLONE_CLOUD_DECRYPT_REMOTE}:$"; then
      echo "Could not find cloud-decrypt remote in rclone.conf at /config/rclone.conf!" | error "[${program_name}] "
      echo "Add a cloud-decrypt remote named \"${RCLONE_CLOUD_DECRYPT_REMOTE}\" or modify the" | error "[${program_name}] "
      echo "RCLONE_CLOUD_DECRYPT_REMOTE environment variable to the correct remote" | error "[${program_name}] "
      check_failed=1
    fi
  fi

  if [ "${MIRROR_VALIDATE_CONFIG}" -eq 1 ]; then
    echo "Validating mirror config because MIRROR_VALIDATE_CONFIG=1" | info "[${program_name}] "
    if ! rclone --config=/config/rclone.conf listremotes | grep -q "^${MIRROR_ENCRYPTED_ENDPOINT}:$"; then
      echo "Could not find encrypted mirror remote in rclone.conf at /config/rclone.conf!" | error "[${program_name}] "
      echo "Add a encrypted mirror remote remote named \"${MIRROR_ENCRYPTED_ENDPOINT}\" or modify the" | error "[${program_name}] "
      echo "MIRROR_ENCRYPTED_ENDPOINT environment variable to the correct remote" | error "[${program_name}] "
      check_failed=1
    fi
    if ! rclone --config=/config/rclone.conf listremotes | grep -q "^${CLOUD_ENCYPTED_ENDPOINT}:$"; then
      echo "Could not find encrypted cloud remote in rclone.conf at /config/rclone.conf!" | error "[${program_name}] "
      echo "Add a encrypted cloud remote remote named \"${CLOUD_ENCYPTED_ENDPOINT}\" or modify the" | error "[${program_name}] "
      echo "CLOUD_ENCYPTED_ENDPOINT environment variable to the correct remote" | error "[${program_name}] "
      check_failed=1
    fi
  fi

fi

if [ "${check_failed}" -eq "1" ]; then
  echo "Configuration errors were detected! To run rclone config, start with interactive \"-it\"" | error "[${program_name}] "
  echo "mode with CONTAINER_START_RCLONE_CONFIG=1" | error "[${program_name}] "
  echo 'docker run -it -v ${PWD}/scripts-data/config:/config -v ${PWD}/scripts-data/log:/log' | error "[${program_name}] "
  echo '-e CONTAINER_START_RCLONE_CONFIG=1 ghcr.io/alexyao2015/cloud-media-scripts' | error "[${program_name}] "
  exit 1
fi
