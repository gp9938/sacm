#!/bin/bash

usage() {
    cat <<EOF
    $0
    
    Clones/checks the config repo for this host and then carries out the updates
EOF
}

get_script_dir() {
    echo $(dirname $(realpath $0))
}

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


# remote 
REMOTE_GIT_BASE_URL="git://wanda.local/"
# need a host repo dir
LOCAL_REPO_BASEDIR="/root/git-config-repos"
APPS_FILE="APPS"
APPS_LAST_PROCESSED_FILE=${APPS_FILE}"_LAST_PROCESSED"
TMP_DIR="/tmp/${basename $0}$$"
APPS_TO_STOP_FILE="${TMP_DIR}/apps_to_stop.txt"
APPS_TO_CLONE_UPDATE_START_FILE="${TMP_DIR}/apps_to_clone_update_start.txt"
DIFF_IGNORED_MOVED="${SCRIPT_DIR}/diff-ignore-moved-lines.sh"

HOST_REPO_NAME=host-${HOSTNAME}
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

if cd ${LOCAL_REPO_BASEDIR}; then
    # good
else
    echo Failed to change dir into LOCAL_REPO_BASEDIR \"${LOCAL_REPO_BASEDIR}\".  Exiting...
    exit 1
fi

#
# First process the host config repo and changes
#
if [ ! -d ${HOST_CONFIG_REPO_DIR} ]; then
    git clone ${REMOTE_GIT_BASE_URL}/${HOST_REPO_NAME}
fi

#
# process APPS file into apps-to-stop file and apps-to-clone-update-start file
#
if cd ${HOST_CONFIG_REPO_DIR} ; then
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
			       
#
# process apps-to-stop file
#
apps_to_stop_file_fd=3
exec ${apps_to_stop_file_fd} <> ${APPS_TO_STOP_FILE}
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

# process apps-to-clone-update-or-start
apps_to_clone_update_start_fd=4
exec ${apps_to_clone_update_start_fd} <> ${APPS_TO_CLONE_UPDATE_START_FILE}
lineNo=1
while read -r -a line -u ${apps_to_clone_update_start_fd}; do
    echo "Processing apps-to-clone-update-start-file \"${APPS_TO_STOP_FILE}\", lineNo: ${lineNo}"
    if [ ! -z ${line[0]} ];then # line should be valid
	repo_name=${line[0]}
	echo "Processing repo ${repo_name}"
	if [ ! -z ${line[1]} ]; then
	    repo_version_number="$line[1]"
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
		git clone ${REMOTE_GIT_BASE_URL}/${repo_name} --branch ${repo_version_number} ${repo_url}
	    else
		echo "Cloning repo ${repo_name} (latest)"
		git clone ${REMOTE_GIT_BASE_URL}/${repo_name} ${repo_url}
	    fi
	else
	    cd ${repo_dir}
	    # repo needs to be updated
	    git fetch --tags
	    if [ ! -z ${repo_version_number} ]; then
		echo "Checking out repo ${repo_name} with tag ${repo_version_number}"
		git checkout ${repo_version_number}
	    else
		echo "Pulling latest revision of repo ${repo_name}"
		git checkout master
	    fi
	fi
	echo "Running start.sh for repo ${repo_name}"
	($({repo_dir}/bin/start.sh))
	
    fi
    ((++lineNo))
done

