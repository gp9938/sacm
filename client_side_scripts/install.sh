#!/bin/bash

#
# Get the sacm daemon installed and running on the given client
#
#

# Return the directory from which a script was run.   If the script
# is reached via symlink,this script will return the directory of the
# symlink because it uses "realpath -s". Function get_real_script_dir
# drops the -s and will therefore return the directory of the
# script file rather than the symlink.
bootstrap_get_script_dir() {
    echo $(dirname $(realpath -s $0))
}

###########################################################################################
# Source client scripts cfg file
CLIENT_SCRIPT_DEFAULTS_FILE="$(bootstrap_get_script_dir)/CLIENT_SCRIPT_DEFAULTS.cfg"

if [ ! -f ${CLIENT_SCRIPT_DEFAULTS_FILE} ]; then
    >&2 echo "Script cfg file, \"${CLIENT_SCRIPT_DEFAULTS_FILE}\", not found.  Exiting."
    exit -1
else
    echo "Client scripts default file is ${CLIENT_SCRIPT_DEFAULTS_FILE}"
    . ${CLIENT_SCRIPT_DEFAULTS_FILE}
    if [ -z ${LOCAL_REPO_BASEDIR} ]; then
	>&2 echo "Script cfg file, \"${CLIENT_SCRIPT_DEFAULTS_FILE}\", did not contain a" \
	    "declaration for LOCAL_REPO_BASEDIR, the top-level dir of all config repos." \
	    "Exiting."
	exit 1
    fi
    if [ -z ${REMOTE_GIT_BASE_URL} ]; then
	>&2 echo "Script cfg file, \"${CLIENT_SCRIPT_DEFAULTS_FILE}\", did not contain a" \
	    "declaration for REMOTE_GIT_BASE_URL, the top-level dir of all config repos." \
	    "Exiting."
	exit 1
    fi    
    if [ -z ${CLIENT_REPO_NAME} ]; then
	>&2 echo "Script cfg file, \"${CLIENT_SCRIPT_DEFAULTS_FILE}\", did not contain a" \
	    "declaration for CLIENT_REPO_NAME, the top-level dir of all config repos." \
	    "Exiting."
	exit 1
    fi    
    if [ -z ${CRONTAB_TIMEDATE_FIELD} ]; then
	>&2 echo "Script cfg file, \"${CLIENT_SCRIPT_DEFAULTS_FILE}\", did not contain a" \
	    "declaration for CRONTAB_TIMEDATE_FIELD, the top-level dir of all config repos." \

	    "Exiting."
	exit 1
    fi    
fi
##########################################################################################

COMMON_SH="$(bootstrap_get_script_dir)/shared_scripts/common.sh"
if [ -f ${COMMON_SH} ]; then
    . ${COMMON_SH}
else
    echo "Cannot load common.sh from ${COMMON_SH}. Exiting..." >&2
    exit 1
fi



REMOTE_REPO_URL="${REMOTE_GIT_BASE_URL}/${CLIENT_REPO_NAME}"
CRONTAB_COMMENT="# automatically added for sacm client_daemon -- do not modify line"
log_info "Checking for availability of repo ${REMOTE_REPO_URL}"
log_command "git ls-remote -q ${REMOTE_REPO_URL}" INFO
if [ $? -ne 0 ]; then
    log_error "Remote repo \"${REMOTE_REPO_URL}\" is not available. Exiting."
    exit 1
fi

if [ ! -d ${LOCAL_REPO_BASEDIR} ]; then
    log_info "Will create local repo basedir ${LOCAL_REPO_BASEDIR}"
    log_command "mkdir -p ${LOCAL_REPO_BASEDIR}" INFO
    log_info "done"
else
    log_info "Local repo basedir ${LOCAL_REPO_BASEDIR} already exists"
fi

cd ${LOCAL_REPO_BASEDIR}

if [ ! -d ${CLIENT_REPO_NAME} ]; then
    log_info "Will run git clone of client repo ${CLIENT_REPO_NAME}"
    log_command "git clone ${REMOTE_REPO_URL}" INFO
    if [ $? -eq  0 ]; then
	log_info "git clone of client repo ${CLIENT_REPO_NAME} succeeded."
    else
	log_error "git clone of client repo ${CLIENT_REPO_NAME} FAILED. Exiting..."
	exit 1
    fi
    log_info "git clone of repo ${CLIENT_REPO_NAME} succeeded."
else
    log_error "Client repo ${CLIENT_REPO_NAME} already exists.  Exiting..."
    exit 1
fi

CLIENT_DAEMON_PATH="${LOCAL_REPO_BASEDIR}/${CLIENT_REPO_NAME}/client_side_scripts/client_daemon.sh"
CRONTAB_ENTRY="${CRONTAB_TIMEDATE_FIELD} ${CLIENT_DAEMON_PATH}"

log_info "Will add sacm daemon crontab entry"
log_command "$(bootstrap_get_script_dir)/install_cron_entry.sh \"${CRONTAB_ENTRY}\" \"${CRONTAB_COMMENT}\"" INFO
if [ $? != 0 ]; then
    log_error "Failed to install cron entry for client_daemon.sh.  Exiting..."
    exit 1
fi

log_info "Will start sacm daemon"
"${CLIENT_DAEMON_PATH}" --action start --background
log_info "Started sacm daemon. Done."
