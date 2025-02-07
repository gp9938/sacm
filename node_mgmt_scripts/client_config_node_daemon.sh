#!/bin/bash
#
#
#
#
#
usage() {
    cat <<EOF
    $0
    
    Loops forever to run the config repo check for this host which then carries out updates
EOF
}

bootstrap_get_script_dir() {
    echo $(dirname $(realpath $0))
}

INTERVAL="1m"
NODE_CONFIG_CHECKER_SCRIPT="$(bootstrap_get_script_dir)/client_config_node_processor.sh"


while /bin/true; do

    scriptLastModTimeBefore=$(stat -c %Y $0)
    echo "Running ${NODE_CONFIG_CHECKER_SCRIPT}"
    ${NODE_CONFIG_CHECKER_SCRIPT}

    #
    # if script was updated, restart
    #
    scriptLastModTimeAfter=$(stat -c %Y $0)
    if [ ${scriptLastModTimeAfter} -gt ${scriptLastModTimeBefore} ]; then
	echo "This script ($0) has been updated.  Restarting..."
	exec $0 $@
    fi
    
    echo "Will sleep for ${INTERVAL}"
    sleep ${INTERVAL}
done
