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

COMMON_SH="$(bootstrap_get_script_dir)/../shared_scripts/common.sh"
if [ -f ${COMMON_SH} ]; then
    . ${COMMON_SH}
else
    echo "Cannot load common.sh. Exiting..." >&2
    exit 1
fi

INTERVAL="1m"
NODE_CONFIG_CHECKER_SCRIPT="$(bootstrap_get_script_dir)/client_config_node_processor.sh"

if [ $# -gt 1 ]; then
    usage
    exit 1
fi

# log file prefix
PRE="/var/tmp/$(basename $0 .sh)_"

#
# Use flog and call get_dated_log_filename each time because this script
# runs 24 hours a day so the log file will need to roll
#
flog $(get_dated_log_filename "${PRE}") "INFO" "$(basename $0) started"

scriptLastModTimeOrig=$(stat -c %Y $0)

while /bin/true; do
    # 
    # Set the log file each loop since this script runs 24/7
    #
    current_log_file=$(get_dated_log_filename "${PRE}")
    log_set_target "${current_log_file}"
    log_info "Running ${NODE_CONFIG_CHECKER_SCRIPT}"
    ${NODE_CONFIG_CHECKER_SCRIPT} "${current_log_file}"

    #
    # See if _this_ script was updated.  If yes, restart this script.
    #
    scriptLastModTimeNew=$(stat -c %Y $0)
    log_info "$0 orig mod time: ${scriptLastModTimeOrig}, new mod time: ${scriptLastModTimeNew}"
    if [ ${scriptLastModTimeNew} -gt ${scriptLastModTimeOrig} ]; then
	log_info "This script ($0) has been updated.  RESTARTING..."
	exec $0 $@
    fi

    #
    log_info "Will sleep for ${INTERVAL}"
    sleep ${INTERVAL}
done
