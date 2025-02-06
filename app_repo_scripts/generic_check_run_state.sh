#!/bin/bash
#
# get the script ignoring symlinks
# 
bootstrap__get_real_script_dir(){
    echo $(dirname $(realpath $0))
}

. "$(bootstrap__get_real_script_dir)/../shared_scripts/common.sh"

exit_if_not_root

if ! generic_init; then
    echo "Init file loading failed.  Exiting..." >&2
    exit 1
fi

CONTAINER_ID=$(docker_get_running_container_id_by_name ${DOCKER_NAME})

if [ ! -z ${CONTAINER_ID} ]; then
    echo "Y:Running"
    exit 0
else
    echo "N:Not running"
    exit 1
fi
