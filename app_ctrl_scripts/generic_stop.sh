#!/bin/bash
#
# get the script ignoring symlinks
# 
boostrap_get_real_script_dir(){
    echo $(dirname $(realpath $0))
}

. "$(bootstrap_get_real_script_dir)/common.sh"

exit_if_not_root

if ! generic_init; then
    "Init file loading failed.  Exiting..." >&2
    exit 1
fi

docker_stop_container_by_name ${DOCKER_NAME}
