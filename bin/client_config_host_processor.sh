#!/bin/bash -x

usage() {
    cat <<EOF
    $0
    
    Clones/checks the config repo for this host and then carries out the updates
EOF
}

get_script_dir() {
    echo $(dirname $(realpath $0))
}

process_apps_to_stop() {
    if [ $(wc -l < ${APPS_TO_STOP_FILE}) -gt 0 ]; then
	#
	# process apps-to-stop file
	#
	apps_to_stop_file_fd=3
	eval exec "${apps_top_file_fd}"'< ${APPS_TO_STOP_FILE}' # set file descriptor (open file)
	lineNo=1
	while read -r -a line -u ${apps_to_stop_file_fd}; do
	    echo "Processing apps-to-stop-file \"${APPS_TO_STOP_FILE}\", lineNo: ${lineNo}"
	    if [ ! -z ${line[0]} ];then # local repo (i.e. app)
		repo_name=${line[0]}
		if [ ! -z ${line[1]} ]; then
		    repo_version_number="$line[1]"
		else
		    repo_version_number=""
		fi
		repo_dir="${LOCAL_REPO_BASEDIR}/${repo_name}"
		repo_url="${REMOTE_GIT_BASE_URL}/${repo_name}"
		
		if [ -d ${repo_dir} ]; then
		    echo "Running stop.sh for repo ${repo_name}"
		    ($({repo_dir}/bin/stop.sh))
		else
		    # Cannot stop an app that has no repo present.   Skipping
		    echo "ERROR: Repo \"${repo_name}\" not found.  Cannot stop this process. Skipping"
		fi
	    fi
	    ((++lineNo))
	done
	exec ${apps_to_stop_fd}>&- # close file descriptor
    else
	echo "File ${APPS_TO_STOP_FILE} is empty.  No actions taken"
    fi # end // process-apps-to-stop wc -l check   
} # end process_apps_to_stop


process_apps_to_clone_update_start() {
    if [ $(wc -l < ${APPS_TO_CLONE_UPDATE_START_FILE}) -gt 0 ]; then
	#
	# process apps-to-clone-update-or-start
	#
	apps_to_clone_update_start_fd=4
	eval exec "${apps_to_clone_update_start_fd}"'< ${APPS_TO_CLONE_UPDATE_START_FILE}'
	
	lineNo=1
	while read -r -a line -u ${apps_to_clone_update_start_fd}; do
	    echo "Processing apps-to-clone-update-start-file " \
		 "\"${APPS_TO_CLONE_UPDATE_START_FILE}\", lineNo: ${lineNo}"
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
		if [ ! -d ${repo_dir} ]; then
		    # repo needs to be cloned
		    cd ${LOCAL_REPO_BASEDIR}
		    if [ ! -z ${repo_version_number} ]; then
			echo "Cloning repo ${repo_name} with version ${repo_version_number}"
			git clone --branch "${repo_version_number}" ${repo_url}
			if [ $? -ne 0 ]; then
			    echo "git clone of ${repo_name} with branch ${repo_version_number} failed. Skipping"
			fi
		    else
			echo "Cloning repo ${repo_name} (latest)"
			git clone ${repo_url}
			if [ $? -ne 0 ]; then
			    echo "git clone of ${repo_name} failed. Skipping"
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
		fi
		if [ -x ${repo_dir}/bin/start.sh ]; then
		    echo "Running start.sh for repo ${repo_name}"
		    ${repo_dir}/bin/start.sh
		else
		    echo "${repo_dir}/bin/start.sh not found. Continuing."
		fi
	    fi
	    ((++lineNo))
	done
	exec ${apps_to_cone_update_start_fd}>&- # close file descriptor
    else
	echo "File ${APPS_TO_CLONE_UPDATE_START_FILE} is empty.  No actions taken"
    fi # end process apps-to-clone-update-or-start
}


# script error checks will not happen if we exit on error (set -e)
set +e
#

# check if client repo directoy exists and exit if not
# If host repo not found
#    clone host repo
# else (host repo found)
#    run a diff to find apps that have been removed and save that list
#    run a diff to find apps that have changed
#    update the repo
#    shutdown the list of apps that have been removed
# fi
# # iterate through Apps file and 

SCRIPT_DIR=$(get_script_dir)
BASE_DIR=$(realpath "${SCRIPT_DIR}/..")
TP_SCRIPTS="${BASE_DIR}/thirdparty/scripts"

# remote 
REMOTE_GIT_BASE_URL="git://wanda.local"
# need a host repo dir
LOCAL_REPO_BASEDIR="${HOME}/git-config-repos"
APPS_FILE="APPS"
APPS_LAST_PROCESSED_FILE=${APPS_FILE}"_LAST_PROCESSED"
TMP_DIR="/tmp/$(basename $0 ".sh")${$}"
APPS_TO_STOP_FILE="${TMP_DIR}/apps_to_stop.txt"
APPS_TO_CLONE_UPDATE_START_FILE="${TMP_DIR}/apps_to_clone_update_start.txt"
DIFF_IGNORED_MOVED="${TP_SCRIPTS}/diff-ignore-moved-lines.sh"

HOST_REPO_NAME="host-${HOSTNAME}"
HOST_CONFIG_REPO_DIR=${LOCAL_REPO_BASEDIR}/${HOST_REPO_NAME}

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
if [ ! -d ${HOST_CONFIG_REPO_DIR} ]; then
    $(git clone ${REMOTE_GIT_BASE_URL}/${HOST_REPO_NAME})
    if [ $? -ne  0 ]; then
	echo "git clone of repo ${HOST_REPO_NAME} FAILED. Exiting..."
	exit 1
    fi
else
    cd ${HOST_CONFIG_REPO_DIR}
    git pull
fi

#
# process APPS file into apps-to-stop file and apps-to-clone-update-start file
#
if cd ${HOST_CONFIG_REPO_DIR}; then
    if [ ! -f ${APPS_LAST_PROCESSED_FILE} ]; then
	# not last processed apps file, new setup -- will process all lines in APPS file
	touch ${APPS_TO_STOP_FILE}
	cp ${APPS_FILE} ${APPS_TO_CLONE_UPDATE_START_FILE}
    else
	diff -u ${APPS_LAST_PROCESSED_FILE} ${APPS_FILE} | ${DIFF_IGNORED_MOVED} \
	    | grep '^< ' | sed -e 's/^< //' > ${APPS_TO_STOP_FILE}
	
	diff -u ${APPS_LAST_PROCESSED_FILE} ${APPS_FILE} | ${DIFF_IGNORED_MOVED} \
	    | grep '^< ' | sed -e 's/^> //' > ${APPS_TO_CLONE_UPDATE_START_FILE}
    fi
else
    echo Could not change dir to HOST_CONFIG_REPO_DIR \"${HOST_CONFIG_REPO_DIR}\".  Exiting...
    exit 1
fi

process_apps_to_stop()

process_apps_to_clone_update_start()

validate_unchanged_apps()

#
#  Success 
#
# copy APPS file to APPS_LAST_PROCESSED
cd ${HOST_CONFIG_REPO_DIR}
cp -p ${APPS_FILE} ${APPS_LAST_PROCESSED_FILE}

# remove TMP_DIR
if [ ! -z ${TMP_DIR} ]; then
    echo "Removing TMP_DIR ${TMP_DIR}"
    rm -rf ${TMP_DIR}
fi
