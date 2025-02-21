#!/bin/bash

DOCKER_NAME="unbound-rpi"
DOCKER_REPO="mvance/unbound-rpi:latest"

exit_if_not_root

docker_stop_container_by_name ${DOCKER_NAME}

