#!/bin/bash

DOCKER_NAME="unbound-rpi"
DOCKER_REPO="mvance/unbound-rpi:latest"

exit_if_not_root

docker_stop_and_remove_container_by_name ${DOCKER_NAME}

docker run \
       --name=${DOCKER_NAME} \
       --volume=${CFG_DIR}/a-records.conf:/opt/unbound/etc/unbound/a-records.conf:ro \
       --publish=53:53/udp \
       --publish=53:53/tcp \
       --restart=unless-stopped \
       --detach=true \
       ${DOCKER_REPO}
