#!/bin/bash

usage() {
    cat <<EOF
    $0
    
    Clones/checks the config repo for this host and then carries out the updates
EOF
}


# Return the directory from which a script was run.   If the script
# is reached via symlink,this script will return the directory of the
# symlink because it uses "realpath -s". Function get_real_script_dir
# drops the -s and will therefore return the directory of the
# script file rather than the symlink.
bootstrap_get_script_dir() {
    echo $(dirname $(realpath -s $0))
}

COMMON_SH="$(bootstrap_get_script_dir)/../shared_scripts/common.sh"
if [ -f ${COMMON_SH} ]; then
    . ${COMMON_SH}
else
    echo "Cannot load common.sh. Exiting..." >&2
    exit 1
fi

process_apps_to_stop() {
    if [ $(wc -l < ${APPS_DEL_FILE}) -gt 0 ]; then
	#
	# process app_del_file
	#
	apps_del_file_fd=3
	eval exec "${apps_del_file_fd}"'< ${APPS_DEL_FILE}' # set file descriptor (open file)
	lineNo=1
	while read -r -a line -u ${apps_del_file_fd}; do
	    echo "Processing apps-to-stop-file \"${APPS_DEL_FILE}\", lin28eNo: ${lineNo}"
	    if [ ! -z ${line[0]} ];then # local repo (i.e. app)
		repo_name=${line[0]}
		if [ ! -z ${line[1]} ]; then
		    repo_version_number="$line[1]"
		else
		    repo_version_number=""
		fi
		repo_dir="${LOCAL_REPO_BASEDIR}/${repo_name}"
		repo_url="${REMOTE_GIT_BASE_URL}/${repo_name}"

		
		if [ -x "${repo_dir}/bin/stop.sh" ]; then
		    echo "Running stop.sh for repo ${repo_name}"
		    ${repo_dir}/bin/stop.sh
		else
		    # Cannot stop an app that has no repo present.   Skipping
		    echo "Warning: ${repo_dir}/bin/stop.sh. Skipping"
		fi
	    fi
	    ((++lineNo))
	done
	eval exec "${apps_del_file_fd}"'<&-' # close file descriptor
    else
	echo "File listing apps to stop is empty (${APPS_DEL_FILE}).  No actions taken."
    fi # end if APPS_DEL_FILE != 0
} # end process_del_file


process_apps_to_clone_update_start() {
    local repo_name
    local repo_version_number
    local repo_dir
    local repo_url
    if [ $(wc -l < ${APPS_ADD_FILE}) -gt 0 ]; then
	#
	# process apps-to-clone-update-or-start
	#
	apps_add_file_fd=4
	eval exec "${apps_add_file_fd}"'< ${APPS_ADD_FILE}'
	
	lineNo=1
	while read -r -a line -u ${apps_add_file_fd}; do
	    echo "Processing apps-add-file from diff_sorter " \
		 "\"${APPS_ADD_FILE}\", lineNo: ${lineNo}"
	    if [ ! -z ${line[0]} ];then # line should be valid
		repo_name=${line[0]}
		echo "Processing repo ${repo_name}"
		if [ ! -z ${line[1]} ]; then
		    repo_version_number="${line[1]}"
		else
		    repo_version_number=""
		fi
		repo_dir="${LOCAL_REPO_BASEDIR}/${repo_name}"
		repo_url="${REMOTE_GIT_BASE_URL}/${repo_name}"
		clone_update_start_app "${repo_name}" "${repo_version_number}" "${repo_dir}" "${repo_url}"
	    fi
	    ((++lineNo))
	done
	
	eval exec "${apps_add_file_fd}"'<&-' # close file descriptor
    else
	echo "File listing apps to clone/update/start is empty (${APPS_ADD_FILE}).  No actions taken."
    fi # end if APPS_ADD_FILE != 0
} # end process_apps_to_clone_update_start

process_apps_to_validate() {
    local repo_name
    local repo_version_number
    local repo_dir
    local repo_url

    unchanged_or_moved_apps=$(cat ${APPS_MOV_FILE} ${APPS_UNC_FILE})
    
    if [ $(wc -l <<<${unchanged_or_moved_apps}) -gt 0 ]; then
	#
	# process unchanged_or_moved_apps
	#
	lineNo=1
	while read -r -a line; do
	    echo "Processing unchanged or moved apps from diff_sorter " \
		 "\"${APPS_MOV_FILE}\" + \"${APPS_UNC_FILE}\", lineNo: ${lineNo}"
	    if [ ! -z ${line[0]} ];then # line should be valid
		repo_name=${line[0]}
		echo "Processing repo ${repo_name}"
		if [ ! -z ${line[1]} ]; then
		    repo_version_number="${line[1]}"
		else
		    repo_version_number=""
		fi
		repo_dir="${LOCAL_REPO_BASEDIR}/${repo_name}"
		repo_url="${REMOTE_GIT_BASE_URL}/${repo_name}"
		val_result=""
		val_repo_result=""
		validate_app ${VAL_TYPE[REPAIR]} "${repo_name}" "${repo_version_number}" \
			     "${repo_dir}" "${repo_url}" val_result val_rep_result    
		if [ $? -ne 0 ]; then
		    echo "Validate app failed for ${repo_name} with val_result \
			 ${VAL_RESULT[${val_result}]} and val_rep_result \
			 ${VAL_REP_RESULT[${val_rep_result}]}"
		else
		    echo "Validate app succeeded for ${repo_name} with val_result \
			 ${VAL_RESULT[${val_result}]} and val_rep_result \
			 ${VAL_REP_RESULT[${val_rep_result}]}"
		fi
	    fi
	    ((++lineNo))
	done <<<${unchanged_or_moved_apps}	
    else
	echo "Files listing moved or unchanged apps are empty (${APPS_MOV_FILE} + ${APPS_UNC_FILE})."\
	     "No actions taken."
    fi # end of wc -l
}

clone_update_start_app() {
    local repo_name=${1}
    local repo_version_number=${2}
    local repo_dir=${3}
    local repo_url=${4}

    local attempt_start="n" # do not attempt to start unless explicitly set below
    if [ ! -d ${repo_dir} ]; then
	# repo needs to be cloned
	cd ${LOCAL_REPO_BASEDIR}
	if [ ! -z ${repo_version_number} ]; then
	    echo "Cloning repo ${repo_name} with version ${repo_version_number}"
	    git clone --branch "${repo_version_number}" ${repo_url}
	    if [ $? -ne 0 ]; then
		echo "git clone of ${repo_name} with branch ${repo_version_number} failed. Skipping"
	    else
		attempt_start="y"
	    fi
	else
	    echo "Cloning repo ${repo_name} (latest)"
	    git clone ${repo_url}
	    if [ $? -ne 0 ]; then
		echo "git clone of ${repo_name} failed. Skipping"
	    else
		attempt_start="y"
	    fi
	fi
    else
	cd ${repo_dir}
	# repo needs to be updated
	git fetch --tags
	if [ ! -z ${repo_version_number} ]; then
	    echo "Checking out repo ${repo_name} with tag ${repo_version_number}"
	    git checkout ${repo_version_number}
	    git pull
	else
	    echo "Pulling latest revision of repo ${repo_name}"
	    git checkout master
	    git pull
	fi
	attempt_start="y"
    fi

    if [ ${attempt_start} = "y" ]; then
	if [ -x "${repo_dir}/bin/start.sh" ]; then
	    echo "Running start.sh for repo ${repo_name}"
	    ${repo_dir}/bin/start.sh
	else
	    echo "WARNING: ${repo_dir}/bin/start.sh not found. Skipping."
	fi
    fi
}


#
# validate_app <validation-type> <repo-name> <repo-version-number> <repo-dir> <repo-url> \
#	       <return-arg:val-result> <return-arg:val-repair-result>
#
# validation-type (VAL_TYPE) can be:
#           CHECK  will go through validation steps of:
#                     repo-exists, repo-up-to-date, container-running
#           REPAIR will check as above and attempt to repair and start the app container
#
# val-result (VAL_RESULT) values:
#           SUCCESS      -- validations steps all completed
#           NO_REPO      -- no repo was found
#           REPO_OOD     -- repo was out of date
#           NOT_RUNNING  -- container was not running
#           ERROR        -- an error occured that prevented validation from completing
#           
# val-repair-result (VAL_REP_RESULT) values:
#           NO_ACTION   -- No action -- repair not requested or not necessary
#           SUCCESS     -- The repair was successful
#           FAILURE     -- The repair was attempted but failed.
#           
#
create_enum VAL_TYPE CHECK REPAIR
create_enum VAL_RESULT SUCCESS NO_REPO REPO_OOD NOT_RUNNING ERROR UNKNOWN
create_enum VAL_REP_RESULT NO_ACTION SUCCESS FAILURE UNKNOWN
validate_app() {
    local l_val_type=${1}
    local repo_name=${2}
    local repo_version_number=${3}
    local repo_dir=${4}
    local repo_url=${5}
    local -n l_val_result=${6}
    local -n l_val_rep_result=${7}

    l_val_result=${VAL_RESULT[UNKNOWN]}
    l_val_rep_result=${VAL_REP_RESULT[UNKNOWN]}
    if [ $(check_valid_enum_elem VAL_TYPE ${l_val_type}) -ne 1 ]; then
	echo "Invalid VAL_TYPE \"${l_val_type}\" received by validate_app.  Cannot continue."
	return 1
    fi
    
    if [ $# -eq 3 ]; then
	local repo_version_number=${3}
    else
	local repo_version_number=""
    fi

    # check if repo exists
    cd ${repo_dir}
    if [ $? -eq 0 ]; then
	# repo exists check git status
	git fetch
	git status | grep -qF "${GIT_STATUS_BRANCH_UP_TO_DATE}"
	if [ $? -eq 0 ]; then
	    # repo is up to date, check if container is running
	    if [ -x "${repo_dir}/bin/check_run_state.sh" ]; then
		${repo_dir}/bin/check_run_state.sh
		if [ $? -ne 0 ]; then
		    l_val_result=${VAL_RESULT[NOT_RUNNING]}
		fi
	    else
		echo "Could not run ${repo_dir}/check_run_state.sh"
		l_val_result=${VAL_RESULT[ERROR]}
	    fi
	else
	    l_val_result=${VAL_RESULT[REPO_OOD]}
	fi 
    else	
	l_val_result=${VAL_RESULT[NO_REPO]}
	echo "WARNING: Issue with ${repo_name}: Could not chdir to ${repo_dir}."
    fi

    if [ ${l_val_result} -eq ${VAL_RESULT[UNKNOWN]} ]; then
	# we got here with not specific validation failure therefore success
	l_val_result=${VAL_RESULT[SUCCESS]}
	l_val_rep_result=${VAL_REP_RESULT[NO_ACTION]}
	return 0
    elif [ ${l_val_type} -eq ${VAL_TYPE[REPAIR]} ]; then
	clone_update_start_app "${repo_name}" "${repo_version_number}" "${repo_dir}" "${repo_url}"
	if [ $? -eq 0 ]; then
	    l_val_rep_result=${VAL_REP_RESULT[SUCCESS]}
	    return 0
	else
	    l_val_rep_result=${VAL_REP_RESULT[FAILURE]}
	fi
    fi
    return 1 
} 

##########################################################################################
# main                                                                                   #
##########################################################################################

# script error checks will not happen if we exit on error (set -e)
set +e
#

SCRIPT_DIR=$(get_script_dir)
BASE_DIR=$(realpath "${SCRIPT_DIR}/..")
SHARED_SCRIPTS_DIR="${BASE_DIR}/shared_scripts"
TP_SCRIPTS="${BASE_DIR}/thirdparty/scripts"

# remote 
REMOTE_GIT_BASE_URL="git://wanda.local"
# need a node repo dir
GIT_STATUS_BRANCH_BEHIND="Your branch is behind"
GIT_STATUS_BRANCH_UP_TO_DATE="Your branch is up to date"
LOCAL_REPO_BASEDIR="${HOME}/git-config-repos"
APPS_FILE="APPS"
APPS_LAST_PROCESSED_FILE=${APPS_FILE}"_LAST_PROCESSED"
TMP_DIR="/tmp/$(basename $0 ".sh")${$}"
NODE_REPO_NAME="node-${HOSTNAME}"
NODE_CONFIG_REPO_DIR=${LOCAL_REPO_BASEDIR}/${NODE_REPO_NAME}
DIFF_IGNORED_MOVED="${TP_SCRIPTS}/diff-ignore-moved-lines.sh"
DIFF_SORTER="${SHARED_SCRIPTS_DIR}/diff_sorter.sh"
DIFF_SORTER_OUTFILES_PREFIX="${TMP_DIR}/out"
APPS_DEL_FILE=${DIFF_SORTER_OUTFILES_PREFIX}"_del.txt"
APPS_MOV_FILE=${DIFF_SORTER_OUTFILES_PREFIX}"_mov.txt"
APPS_UNC_FILE=${DIFF_SORTER_OUTFILES_PREFIX}"_unc.txt"
APPS_ADD_FILE=${DIFF_SORTER_OUTFILES_PREFIX}"_add.txt"


if mkdir ${TMP_DIR}; then
    echo Created TMP_DIR \"${TMP_DIR}\"
else
    echo Could not create TMP_DIR \"${TMP_DIR}\". Exiting...
    exit 1
fi

if [ ! -d ${LOCAL_REPO_BASEDIR} ]; then
    echo Could not find LOCAL_REPO_BASEDIR \"${LOCAL_REPO_BASEDIR}\".  Will attempt to create...
    if mkdir ${LOCAL_REPO_BASEDIR}; then
	echo Successfully created LOCAL_REPO_BASEDIR \"${LOCAL_REPO_BASEDIR}\".
    else
	echo Could not create LOCAL_REPO_BASEDIR \"${LOCAL_REPO_BASEDIR}\".  Exiting...
	exit 1
    fi
fi

cd ${LOCAL_REPO_BASEDIR}
if [ $? -ne 0 ]; then
    echo Failed to change dir into LOCAL_REPO_BASEDIR \"${LOCAL_REPO_BASEDIR}\".  Exiting...
    exit 1
fi

#
# First process the host config repo and changes 
# 
if [ ! -d ${NODE_CONFIG_REPO_DIR} ]; then
    $(git clone ${REMOTE_GIT_BASE_URL}/${NODE_REPO_NAME})
    if [ $? -ne  0 ]; then
	echo "git clone of repo ${NODE_REPO_NAME} FAILED. Exiting..."
	exit 1
    fi
else
    cd ${NODE_CONFIG_REPO_DIR}
    git pull
fi

#
# process APPS file into apps-to-stop file and apps-to-clone-update-start file
#
if cd ${NODE_CONFIG_REPO_DIR}; then
    # APPLS_LAST_PROCESSED_FILE may not exist -- diff_sort handles this situation
    # and will consider an empty file instead.
    ${DIFF_SORTER} --outfiles-prefix ${DIFF_SORTER_OUTFILES_PREFIX} \
		   --ln-del none --ln-width 0 \
		   ${APPS_LAST_PROCESSED_FILE} ${APPS_FILE}
else
    echo "Could not change dir to NODE_CONFIG_REPO_DIR \"${NODE_CONFIG_REPO_DIR}\".  Exiting..."
    exit 1
fi

process_apps_to_stop

process_apps_to_clone_update_start

process_apps_to_validate

#
#  Success 
#
# copy APPS file to APPS_LAST_PROCESSED
cd ${NODE_CONFIG_REPO_DIR}
cp -p ${APPS_FILE} ${APPS_LAST_PROCESSED_FILE}

# remove TMP_DIR
if [ ! -z ${TMP_DIR} ]; then
    echo "Removing TMP_DIR ${TMP_DIR}"
    rm -rf ${TMP_DIR}
fi
