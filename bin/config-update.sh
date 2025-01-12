#!/bin/bash
#
usage() {
    cat <<EOF
    $0	<config-repo-name> <comment> [new-config-version]

    config-repo-name      Supply "." to indicate the parent directory is the name of the config repo.
    comment               The comment (in quotes) to be included in the commit 
    new-version-number    Optionally provide the new version number for the config.   Otherwise,
                          the version number in ${VERSION_FILE} will be incremented by 0.01.  If
			  ${VERSION_FILE} does not exist or is empty, the version 1.0 will be applied.
EOF
}

get_script_dir() {
    echo $(dirname $(realpath $0))
}

increment_version_number() {
    if [ $# -eq 1 ]; then
	local current_version=${1}
    else
	local current_version=""
    fi
    
    local new_version
    if [ -z ${current_version} ]; then
	current_version="1.0"
	new_version=${current_version}
    else
	new_version=$(echo ${current_version} + "0.01" | bc -l)
    fi

    echo ${new_version}
}

VERSION_FILE="CONFIG_VERSION"
PRIOR_VERSION_FILE="PRIOR_CONFIG_VERSION"

SCRIPT_CFG_FILE=$(get_script_dir)"/../cfg/"$(basename ${0} .sh)".cfg"
if [ ! -f ${SCRIPT_CFG_FILE} ]; then
    >&2 echo Script cfg file, \"${SCRIPT_CFG_FILE}\", not found.  Exiting.
    exit -1
else
    echo $SCRIPT_CFG_FILE
    . ${SCRIPT_CFG_FILE}
    if [ -z ${CONFIG_REPO_DIR} ]; then
	>&2 echo Script cfg file, \"${SCRIPT_CFG_FILE}\", did not contain a \
	    declaration for CONFIG_REPO_DIR.  Exiting.
	exit -1
    fi
fi

if [ $# -lt 2 ]; then
   usage
   exit -1
fi

config_repo_name=${1}

if [ ${config_repo_name} = "." ]; then
    config_repo_name=$(basename $(realpath $(pwd)))
fi

repo_dir=${CONFIG_REPO_DIR}/${config_repo_name}
if cd ${repo_dir}; then
    echo Changed dir to ${repo_dir} "("$(pwd)")"
else
    echo Could not change dir to git config repo ${repo_dir}.  Exiting....
    exit -1
fi

comment=${2}
if [ $# -gt 2 ]; then
    new_config_version=${3}
else
    if [ -f ${VERSION_FILE} ]; then
	config_version=$(cat ${VERSION_FILE})
    fi

    new_config_version=$(increment_version_number ${config_version})
fi



if [ -f ${VERSION_FILE} ]; then
    mv ${VERSION_FILE} ${PRIOR_VERSION_FILE}
fi

echo ${new_config_version} > ${VERSION_FILE}

if [ -z "$(git status --porcelain)" ]; then
    echo "No changes to commit in ${repo_dir}.  Exiting..."
    exit -1
fi

git add .
git commit -m "${comment}"
git tag -a "${new_config_version}" -m "${comment}"



