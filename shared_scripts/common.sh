#!/bin/bash
export API_VERSION="1.0"

FUNC_BEFORE_COMMON=$(declare -F|awk '{print $3}' | sort -u)

#
# constants (consts)
#
readonly REGEX_INT='^[0-9]+$'
readonly DEFAULT_LOG_TARGET=1 # file descritor 1
readonly LOG_DATETIME_FORMAT="+%Y%m%d-%H:%M:%S"

# Public
#
# Return the directory from which a script was run.   If the script
# is reached via symlink,this script will return the directory of the
# symlink because it uses "realpath -s". Function get_real_script_dir
# drops the -s and will therefore return the directory of the
# script file rather than the symlink.
# Note: ${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]} is a reliable way
# to isolate $0 from sourced file situations and from function
# protection (when ${BASH_SOURCE[0]} may not work)
get_script_dir() {
    echo $(dirname $(realpath -s ${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}))
}

# Public
#
# Return s the directory from which a script was run.  If the
# script is reached via a symlink, the directory of the script
# and not the symlink will be returned.  Use get_script_dir
# if you want the directory of a symlink to be returned.
get_real_script_dir(){
    echo $(dirname $(realpath ${BASH_SOURCE[${#BASH_SOURCE[@]} - 1]}))
}

get_current_script_dir(){
    echo $(dirname $(realpath ${BASH_SOURCE[0]}))
}

get_base_dir() {
    echo $(realpath "$(get_script_dir)/..")
}

get_cfg_dir() {
    echo "$(get_base_dir)/cfg"
}

get_dated_log_filename() {
    if [ $# -gt 0 ]; then
	local prefix=${1}
    else
	local prefix="L"
    fi

    echo "${prefix}$(date +%Y%m%d).log"
}



log_set_target() {
    if [ $# -lt 1 ]; then
	echo "log_set_target needs one argument, a file or file descriptor." >&2
	return 1
    fi

    LOG_TARGET=${1}
}

#
# Log to a pre-set log target (@see log_set_target) or to stdout if not set
#
# log <log-level> <text> <...>
#
# e.g.: log INFO "my log text"
#
log() {
    flog ${LOG_TARGET:-${DEFAULT_LOG_TARGET}} ${log_level} $@
}

#
# Log to a pre-set log target (@see log_set_target) or to stdout if not set using
# log-level INFO
#
# e.g. log_info "my log text"
log_info() {
    log INFO $@
}

#
# Log to a pre-set log target (@see log_set_target) or to stdout if not set using
# log-level WARN
#
# e.g. log_warn "my log text"
log_warn() {
    log WARN $@
}

#
# Log to a pre-set log target (@see log_set_target) or to stdout if not set using
# log-level ERROR
#
# e.g. log_error "my log text"
log_error() {
    log ERROR $@
}


#
# Run a command and write the output of the command to a preset log target or
# to stdout
#
# log_command <command-string> <log-level>
#
log_command() {
    if [ $# -lt 2 ]; then
	echo "Incorrect argument count received by log_command in $(basename $0).  "\
	     "Received \"$1\" " >&2
	return 1
    fi

    local command_string="${1}"; shift
    local log_level=${1}; shift
    flog_command "${command_string}" ${LOG_TARGET:-${DEFAULT_LOG_TARGET}} ${log_level} $@
    return $?
}

#
#  Prefix stdin text with date/time/log-level and write to log file
#
#  flogging_filter <file-or-fd> <log-level> <line-prefix> [READS-FROM-STDIN]
#
#  eg. flogging_filter "myLogFile" INFO <<<$(grep foo /tmp/myfile)
#
flogging_filter() {
    if [ $# -lt 2 ]; then
	echo "Incorrect argument count received by function flog in $(basename $0).  " \
	     "Received \"$@\" " >&2
	return 1
    fi

    local log_target=${1}; shift
    local log_level=${1}; shift
    local line_prefix=${1}; shift
    while IFS= read -r line; do
	printf -v output '%s %s %s %s' "$(date ${LOG_DATETIME_FORMAT})" "${log_level}" "${line_prefix}" "$line"
	if [[ ${log_target} =~ ${REGEX_INT} ]]; then
	    # is a file descriptor
	    echo "${output}" >&${log_target}
	else
	    # is a file name
	    echo "${output}" >> ${log_target}
	fi
	
    done
}

#
# Write date/time/log-level text to log file
#
# flog <file-or-fd> <log-level> <text> <...>
#
#   e.g. flog "myLogFile" INFO "hello world"
#
flog() {
    if [ $# -lt 3 ]; then
	echo "Incorrect argument count received by function flog in $(basename $0).  " \
	     "Received \"$@\" " >&2
	return 1
    fi
    
	
    local log_target=${1}; shift
    local log_level=${1}; shift
    local log_line="$(date ${LOG_DATETIME_FORMAT}) ${log_level} $@"
    
    if [[ ${log_target} =~ ${REGEX_INT} ]]; then
	# is a file descriptor
	echo "${log_line}" >&${log_target}
    else
	# is a file name
	echo "${log_line}" >> ${log_target}
    fi
}

#
# Run a command and write the output of the command to the log file
#
# flog_command <command-string> <file-or-fd> <log-level>
#
# returns the status of the command it ran
#
flog_command() {
    if [ $# -lt 3 ]; then
	echo "Incorrect argument count received by flog_command in $(basename $0).  "\
	     "Received \"$@\" " >&2
	return 1
    fi

    local command_string="${1}"; shift
    local log_target=${1}; shift
    local log_level=${1}; shift
    
    flog "${log_target}" ${log_level} "cmd> Will run command ${command_string}"
    (eval ${command_string}) 2>&1 | flogging_filter ${log_target} ${log_level} "cmd>  "

    # return the status of the command
    return ${PIPESTATUS[0]}
}

flog_info() {
    flog INFO $@
}

flog_warn() {
    log WARN $@
}

flog_error() {
    log ERROR $@
}

docker_get_container_id_by_name() {
    local name=${1}
    if [ $# -gt 1 ]; then
	local -n l_container_id=${2}
    else
	local l_container_id
    fi
    # look for all 
    l_container_id=$(docker ps -aq --filter name="${name}" )
    if [ $? != 0 ]; then
	return 1;
    fi
    
    if [ $# -eq 1 ]; then
	# echo only if not returning by reference (e.g. local -n)
	echo ${l_container_id}
    fi
}


docker_get_running_container_id_by_name() {
    local name=${1}
    if [ $# -gt 1 ]; then
	local -n l_container_id=${2}
    else
	local l_container_id
    fi
    # look for only running (not -a for all)
    l_container_id=$(docker ps -q --filter name="${name}" )
    if [ $? != 0 ]; then
	return 1;
    fi

    if [ $# -eq 1 ]; then
	# echo only if not returning by reference (e.g. local -n)
	echo ${l_container_id}
    fi
}

docker_stop_container_by_name() {
    local name=${1}
    local container_id

    docker_get_container_id_by_name ${name} container_id
    if [ $? != 0 ]; then
	return 1;
    fi

    if [ ! -z ${container_id} ]; then
	docker_stop_container_by_id ${container_id}	
	if [ $? != 0 ]; then
	    return 1;
	else
	    return 0
	fi
    else
	return 1
    fi
}

docker_stop_and_remove_container_by_name() {
    local name=${1}
    local container_id

    docker_get_container_id_by_name ${name} container_id
    if [ $? != 0 ]; then
	return 1;
    fi

    if [ ! -z ${container_id} ]; then
	docker_stop_container_by_id ${container_id}
	docker_remove_container_by_id ${container_id}
	return 0
    else
	return 1
    fi
}

docker_stop_container_by_id(){
    local container_id=${1}

    docker stop ${container_id}
}

docker_remove_container_by_id() {
    local container_id=${1}

    docker stop ${container_id}
    docker rm ${container_id}
}

exit_if_not_root() {
    if [ $(id -u) -ne 0 ]; then
	local message="This script uses docker and must run as root.  Exiting..."
        echo -e "\n${message}\n" >&2
	log_error "${message}"
        exit 1
    fi
}


#
# Initializes env REPO_DIR and REPO_CFG_DIR and
# calls generic_load_init_cfg
#
#
generic_init() {
    REPO_DIR=$(get_base_dir)
    REPO_CFG_DIR="${REPO_DIR}/cfg"

    if generic_load_init_cfg; then
	return 0
    else
	return 1
    fi
}


#
# Load the INIT.cfg file found in the directory where the
# the script or symlink to that script is found.
#
# returns 0 upon success and 1 upon failure
#
generic_load_init_cfg() {
    #
    # INIT_FILE must contain variable definitions for DOCKER_NAME
    # and DOCKER_RUN_COMMAND
    # Once defined, you may symlink start.sh and stop.sh from that directory to
    # generic_start.sh and generic_stop.sh respectively.
    # get_script_dir loads the dir of a symlink if this script is being used
    # in that manner by using "realpath -s".  If get_script_dir use
    # realpath without -s the INIT.cfg path would point to the common
    # script directory instead.
    INIT_FILE="$(get_script_dir)/INIT.cfg"
    
    if [ ! -f ${INIT_FILE} ]; then
	echo "Configuration ${INIT_FILE} not found." >&2
	return 1
    fi
    
    . ${INIT_FILE}
    
    echo "DOCKER_NAME is ${DOCKER_NAME}"
    
    if [ -z ${DOCKER_NAME} ]; then
	local message
	message="${INIT_FILE} did not define DOCKER_NAME. "
	message+="Both DOCKER_NAME and DOCKER_RUN_COMMAND must "
	message+="be defined.  Returning error status."
	log_error "${message}"
	echo "${message} " >&2
	return 1
    fi

    if [ -z "${DOCKER_RUN_COMMAND}" ]; then
	local message
	message="${INIT_FILE} did not define DOCKER_RUN_COMMAND. "
	message+="Both DOCKER_NAME and DOCKER_RUN_COMMAND must "
	message+="be defined.  Returning error status."
	log_error "${message}"
	echo "${message}" >&2
	return 1
    fi

    return 0
}

FUNC_AFTER_COMMON=$(declare -F|awk '{print $3}' | sort -u)

ENUM_SH="$(get_current_script_dir)/../shared_scripts/enum.sh"
if [ -f ${ENUM_SH} ]; then
    . ${ENUM_SH}
else
    echo "common.sh cannot load ${ENUM_SH}.  Exiting..." >&2
    exit 1
fi



NEW_FUNCS=$( diff <(echo -e "${FUNC_BEFORE_COMMON}") <(echo -e "${FUNC_AFTER_COMMON}" )  | fgrep '>')


# while IFS= read -r line;  do
#     echo ${line:1}
# done <<<${NEW_FUNCS}

#
# Incomplete -- will swtich to bats system
#
test_common() {
    echo -n "check docker_get_container_id_by_name"
    if docker_get_container_id_by_name no_such_container; then echo PASS; else echo FAIL; fi


    echo -n "docker_get_running_container_id_by_name: "
    if docker_get_running_container_id_by_name no_such_container; then echo PASS; else echo FAIL; fi
    echo -n "docker_remove_container_by_id: "
    if docker_remove_container_by_id NOSUCHID; then echo PASS; else echo FAIL; fi
    echo -n "docker_stop_and_remove_container_by_name: "
    if docker_stop_and_remove_container_by_name no_such_container; then echo PASS; else echo FAIL; fi
    echo -n "docker_stop_container_by_id: "
    if docker_stop_container_by_id NOSUCHID; then echo PASS; else echo FAIL; fi
    echo -n "docker_stop_container_by_name: "
    if docker_stop_container_by_name no_such_container; then echo PASS; else echo FAIL; fi
    echo -n "exit_if_not_root: "
    if (exit_if_not_root); then echo PASS; else echo FAIL; fi
    echo -n "generic_init: "
    if generic_init; then echo PASS; else echo FAIL; fi
    echo -n "generic_load_init_cfg: "
    if generic_load_init_cfg; then echo PASS; else echo FAIL; fi
    echo -n "get_base_dir: "
    if get_base_dir; then echo PASS; else echo FAIL; fi
    echo -n "get_cfg_dir: "
    if get_cfg_dir; then echo PASS; else echo FAIL; fi
    echo -n "get_real_script_dir: "
    if get_real_script_dir; then echo PASS; else echo FAIL; fi
    echo -n "get_script_dir: "
    if get_script_dir; then echo PASS; else echo FAIL; fi
    echo -n "log: "
    if log "test message"; then echo PASS; else echo FAIL; fi
    echo -n "log_error: "
    if log_error "test message"; then echo PASS; else echo FAIL; fi
    echo -n "log_info: "
    if log_info "test message"; then echo PASS; else echo FAIL; fi
    echo -n "log_warn: "
    if log_warn "test message"; then echo PASS; else echo FAIL; fi
    echo status is $?
}

