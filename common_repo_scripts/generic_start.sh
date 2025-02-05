#!/bin/bash

#
# get the script ignoring symlinks
# 
_get_real_script_dir(){
    echo $(dirname $(realpath $0))
}

. "$(_get_real_script_dir)/common.sh"

exit_if_not_root

if ! generic_init; then
    echo "Init file loading failed.  Exiting..."
    exit 1
fi

docker_stop_and_remove_container_by_name ${DOCKER_NAME}

${DOCKER_RUN_COMMAND}
