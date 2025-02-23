#!/bin/bash
#
usage() {
    cat <<EOF
    $0 [-s|--scripts-check <type>] \\
           <config-update-comment> [new-config-version]

    Run this command from within the client or app config repo (e.g. \$HOME/localgit/app-unbound-pi5 or
    \$HOME/localgit/client-pi5)

    OPTIONS
    <config-update-comment>  The comment (in quotes) to be included in the commit 
    [new-version-number]     Optionally provide the new version number for the config.   Otherwise,
                             the version number in ${CONFIG_VERSION_FILE} will be incremented by 0.01.  If
			     ${CONFIG_VERSION_FILE} does not exist or is empty, the version number
			     of 1.0 will be applied.
    -s|--scripts-check <type>
			     The scripts-check will, depending on the type provided, 
			     will compare the version of the app or client repo's current copy version
			     of the script dirs to the version of the sources.

	       		     <type> can be "update" (default), "check", "prompt", or "skip"
			     type "update" will trigger an update to the latest version
			     type "check" will check the version and report it
			     type "prompt" will check the version and, if a newer version is available,
			       prompt the user to update it (non-interactive use will cause the script
			       to exit)
			     type <skip> will skip the check entirely.
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



perform_script_dir_check() {
    local type=${1}
    local script_dir_name=${2}
    local update="n"

    local src_script_dir="${BASE_DIR}/${script_dir_name}"
    
    if [ ${type} = "skip" ]; then
	return 0
    fi

    if [ ! -d ${src_script_dir} ]; then
	>2& echo "Script directory \"${src_script_dir}\" not found.  Cannot perform check. "
	return 1
    fi

    if [ ! -d ${script_dir_name} ]; then
	echo "Repo does not have a copy of the \"${src_script_dir}\" scripts directory.  Will create a copy."
	echo "Will copy from \"${src_script_dir}\" to \".\""
	if rsync -par ${src_script_dir} .; then
	    echo "Script directory copy \"${src_script_dir}\" created."
	    return 0
	else
	    echo "Error creating script directory copy of \"${src_script_dir}\""
	    return 1
	fi
    else
	pwd
        local src_script_dir_version=$(cat ${src_script_dir}/${VERSION_FILE})
	local repo_script_dir_version=$(cat ./${script_dir_name}/${VERSION_FILE})
	echo "src_script_dir_version is ${src_script_dir_version}"
	echo "repo_script_dir_version is ${repo_script_dir_version}"
	if [[ ${src_script_dir_version} > ${repo_script_dir_version} ]]; then
	    echo "Src script dir (${script_dir_name} version  ${src_script_dir_version} is greater than" \
		 "that of the copy found in this repo (version ${repo_script_dir_version})."
	    
	    case ${type} in
		check)
		    echo "Provide --scripts-check type \"update\" to update"
		    ;;
		update)
		    echo " Will update."
		    update="y"
		    ;;
		prompt)
		    local response="u"
		    local responseRegEx="^[yn]$"
		    while [[ ! "${response}" =~ ${responseRegEx} ]]; do
			echo -n "Update copy of ${script_dir_name}? (y/n): "
			read response
		    done
		    if [ ${response} = "y" ]; then
			update="y"
		    fi
		    ;;
		*)
		    2>& echo "Unknown crs-check type ${type} provided.  Will ignore"
		    ;;
	    esac

	    if [ ${update} = "y" ]; then
		cp -p ./${script_dir_name}/${VERSION_FILE} ./${script_dir_name}/${PRIOR_VERSION_FILE} 
		if rsync -par ${src_script_dir} .; then
		    echo "Update complete"
		else
		    echo "Update failed"
		fi
	    fi
	fi
    fi
    
}

readonly CLIENT_REPO_PREFIX="client-"
readonly APP_REPO_PREFIX="app-"
readonly REPO_TYPE_CLIENT="client"
readonly REPO_TYPE_APP="app"
REPO_DIR=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename ${REPO_DIR})
BASE_DIR="$(realpath $(get_script_dir)/..)"

APP_REPO_SCRIPT_DIRS="app_ctrl_scripts shared_scripts"
CLIENT_REPO_SCRIPT_DIRS="client_side_scripts shared_scripts"
	
CRS_SRC_DIR="${BASE_DIR}/common_repo_scripts"
CRS_DIR="common_repo_scripts"
CRS_VERSION_FILE="VERSION"
CRS_PRIOR_VERSION_FILE="PRIOR_VERSION"
CONFIG_VERSION_FILE="CONFIG_VERSION"
CONFIG_PRIOR_VERSION_FILE="CONFIG_PRIOR_VERSION"
VERSION_FILE="VERSION"
PRIOR_VERSION_FILE="PRIOR_VERSION"

if [ $# -lt 1 ]; then
   usage
   exit 1
fi

case ${REPO_NAME} in
    ${APP_REPO_PREFIX}*)
 	REPO_TYPE="app"
	;;
    ${CLIENT_REPO_PREFIX}*)
	REPO_TYPE="client"
	;;
    *)
	echo "Unknown prefix for repo ${REPO_NAME}.  Exiting..." >&2
	exit 1
	;;
esac

cd ${REPO_DIR}


###########################################################
# Source Script CFG file
SCRIPT_CFG_FILE="${BASE_DIR}/cfg/$(basename ${0} .sh).cfg"

if [ ! -f ${SCRIPT_CFG_FILE} ]; then
    >&2 echo Script cfg file, \"${SCRIPT_CFG_FILE}\", not found.  Exiting.
    exit -1
else
    echo $SCRIPT_CFG_FILE
    . ${SCRIPT_CFG_FILE}
    if [ -z ${CONFIG_REPO_DIR} ]; then
	>&2 echo "Script cfg file, \"${SCRIPT_CFG_FILE}\", did not contain a" \
	    "declaration for CONFIG_REPO_DIR, the top-level dir of all config repos." \
	    "Exiting."
	exit 1
    fi
fi
###########################################################

scripts_check_type="update"
while [[ $# -gt 0 ]]; do
    case $1 in
	-c|--scripts-check)
	    scripts_check_type=$2
	    ;;
	-h|--h*)
	    usage
	    exit 1
	    ;;
	*)
	    POSITIONAL_ARGS+=("$1") # save positional arg
	    shift # past argument
	    ;;
    esac	
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters



comment=${1}
if [ $# -gt 1 ]; then
    new_config_version=${2}
else
    if [ -f ${CONFIG_VERSION_FILE} ]; then
	config_version=$(cat ${CONFIG_VERSION_FILE})
    fi

    new_config_version=$(increment_version_number ${config_version})
fi

case ${REPO_TYPE} in
    ${REPO_TYPE_APP})
	for script_dir in ${APP_REPO_SCRIPT_DIRS}; do 
	    perform_script_dir_check ${scripts_check_type} ${script_dir}
	done
	;;
    ${REPO_TYPE_CLIENT})
	for script_dir in ${CLIENT_REPO_SCRIPT_DIRS}; do 
	    perform_script_dir_check ${scripts_check_type} ${script_dir}
	done
	;;
esac	

if [ -f ${CONFIG_VERSION_FILE} ]; then
    mv ${CONFIG_VERSION_FILE} ${CONFIG_PRIOR_VERSION_FILE}
fi

echo ${new_config_version} > ${CONFIG_VERSION_FILE}

if [ -z "$(git status --porcelain)" ]; then
    echo "No changes to commit in ${repo_dir}.  Exiting..."
    exit -1
fi

echo "Running git add ."
git add .
echo "Running git commt -m ${comment}"
git commit -m "${comment}"
echo "Running git tag ${new_config_version} -m ${comment}"
git tag -a "${new_config_version}" -m "${comment}"
echo "Running git push"
git push




