#!/bin/bash
#
#
#
#
#
usage() {
    cat <<EOF
    $0 <-a|--action> <action> <-b|--background>
    
    Loops forever to run the config repo check for this host which then carries out updates

    <-a|--action> <action> - Provide action of start, stop, or check. 
    		  	     Note that only one instance per login will start.
    <-b|--background> - Will background the process if provided action is "start"

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

action="none"
background="n"
while [[ $# -gt 0 ]]; do
    case $1 in
	-a|--action)
	    case $2 in
		start|stop|check)
		    action=$2 scripts_check_type=$2
		    ;;
		*)
		    echo -e "Unknown action \"$2\" provided.\n" >&2
		    usage
		    exit 1
		    ;;
	    esac
	    shift
	    shift
	    ;;
	-b|--background)
	    background="y"
	    shift
	    ;;
	-h|--h*)
	    usage
	    exit 1
	    ;;
	*)
	    echo -e "Unknown argument $1.\n" >&2
	    usage
	    exit 1
	    ;;
    esac	
done

if [ ${action} = "none" ]; then
    echo -e "Expected action parameter.\n" >&2
    usage
    exit 1
fi

PROCESS_NAME=$(basename $0)
PID_FILE="/var/tmp/$(basename $0 .sh)_${USER}.PID"
INTERVAL="1m"
CLIENT_PROCESSOR_SCRIPT="$(bootstrap_get_script_dir)/client_processor.sh"
# log file prefix
PRE="/var/tmp/$(basename $0 .sh)_"

case ${action} in
    start)
	if [ -f ${PID_FILE} ]; then
	    PID=$(cat ${PID_FILE})
	    if [ -d "/proc/${PID}" ]; then
		echo "${PROCESS_NAME} is already running as pid ${PID}."
		exit 1
	    fi
	fi
	;;
    stop)
	if [ -f ${PID_FILE} ]; then
	    PID=$(cat ${PID_FILE})
	    rm ${PID_FILE}
	    if [ -d "/proc/${PID}" ]; then
		echo "Sending kill to pid ${PID}"
		kill ${PID}
		sleep 1
		if [ -d "/proc/${PID}" ]; then
		    echo "${PID} still running will send kill -9"
		    kill -9 ${PID}
		    sleep 1
		    if [ -d "/proc/${PID}" ]; then
			echo "${PID} still running.  ERROR"
			exit 1;
		    fi
		fi
		echo "${PROCESS_NAME} stopped."
		exit 0
	    else
		echo "${PID} for ${PROCESS_NAME} not running."
		exit 0
	    fi
	else
	    echo "No process id file found for ${PROCESS_NAME}."
	    exit 0
	fi
	;;
    check)
	if [ -f ${PID_FILE} ]; then
	    PID=$(cat ${PID_FILE})
	    if [ -d "/proc/${PID}" ]; then
		echo "${PROCESS_NAME} is running as pid ${PID}"
	    else
		rm ${PID_FILE}
		echo "${PROCESS_NAME} pid ${PID} is not running. Pid file removed."
	    fi
	else
	    echo "${PROCESS_NAME} is not running."
	fi
	exit 0
	;;
esac


echo -e "$(basename $0) started at $(date)\n"
STDERR_OUTFILE="/var/tmp/$(basename $0 .sh)_stderr.log"
# Re-spawn as a background process, if we haven't already.
if [[ ${background} = "y" ]]; then
    echo "Will background $(basename $0)"
    if [ -f "${STDERR_OUTFILE}" ]; then
	mv "${STDERR_OUTFILE}" "${STDERR_OUTFILE}.old"
    fi
    nohup "$0 --action start"  > "${STDERR_OUTFILE}" 2>&1 &
    exit $?
else
    tty > /dev/null
    if [ $? = 0 ]; then
	# only print if attached to a tty
	echo "Will not background $(basename $0), supply --background to background"
    fi
fi

echo $$ > ${PID_FILE}


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
    log_info "Running ${CLIENT_PROCESSOR_SCRIPT}"
    ${CLIENT_PROCESSOR_SCRIPT} "${current_log_file}"

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
