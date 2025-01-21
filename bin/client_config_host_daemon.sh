#!/bin/bash

usage() {
    cat <<EOF
    $0
    
    Loops forever to run the config repo check for this host which then carries out updates
EOF
}

get_script_dir() {
    echo $(dirname $(realpath $0))
}

INTERVAL="1m"
HOST_CONFIG_CHECKER_SCRIPT="$(get_script_dir)/client_config_host_processor.sh"


while /bin/true; do
    echo "Running ${HOST_CONFIG_CHECK_SCRIPT}"
    ($(${HOST_CONFIG_CHECKER_SCRIPT}))

    echo "Will sleep for ${INTERVAL}"
    sleep ${INTERVAL}
done
