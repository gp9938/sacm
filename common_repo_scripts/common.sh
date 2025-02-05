#!/bin/sh
export API_VERSION="1.0"

# Public
#
# Return the directory from which a script was run.   If the script
# is reached via symlink,this script will return the directory of the
# symlink because it uses "realpath -s". Function get_real_script_dir
# drops the -s and will therefore return the directory of the
# script file rather than the symlink.
get_script_dir() {
    echo $(dirname $(realpath -s $0))
}

# Public
#
# Return s the directory from which a script was run.  If the
# script is reached via a symlink, the directory of the script
# and not the symlink will be returned.  Use get_script_dir
# if you want the directory of a symlink to be returned.
get_real_script_dir(){
    echo $(dirname $(realpath $0))
}

get_base_dir() {
    echo $(realpath "$(get_script_dir)/..")
}

get_cfg_dir() {
    echo "$(get_base_dir)/cfg"
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

    if [ $# -eq 1 ]; then
	# echo only if not returning by reference (e.g. local -n)
	echo ${l_container_id}
    fi
}

docker_stop_container_by_name() {
    local name=${1}
    local container_id

    docker_get_container_id_by_name ${name} container_id

    if [ ! -z ${container_id} ]; then
	docker_stop_container_by_id ${container_id}
	return 0
    else
	return 1
    fi
}

docker_stop_and_remove_container_by_name() {
    set -x
    echo "docker_stop_and_remove_container_by_name ${1}"
    local name=${1}
    local container_id

    docker_get_container_id_by_name ${name} container_id

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
        echo "" >&2
        echo "This script uses docker and must run as root.  Exiting." >&2
        echo "" >&2
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
	echo "${INIT_FILE} did not define DOCKER_NAME. " \
	     "Both DOCKER_NAME and DOCKER_RUN_COMMAND must " \
	     "be defined.  Exiting..." >&2
	return 1
    fi

    if [ -z "${DOCKER_RUN_COMMAND}" ]; then
	echo "${INIT_FILE} did not define DOCKER_RUN_COMMAND. " \
	     "Both DOCKER_NAME and DOCKER_RUN_COMMAND must " \
	     "be defined.  Exiting..." >&2
	return 1
    fi

    return 0
}
