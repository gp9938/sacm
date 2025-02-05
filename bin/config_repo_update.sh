#!/bin/bash
#
usage() {
    cat <<EOF
    $0 [-c|--crs-check <type>] \\
           <config-update-comment> [new-config-version]

    Run this command from within the config repo (e.g. \$HOME/localgit/unbound-pi5)

    OPTIONS
    <config-update-comment>  The comment (in quotes) to be included in the commit 
    [new-version-number]     Optionally provide the new version number for the config.   Otherwise,
                             the version number in ${CONFIG_VERSION_FILE} will be incremented by 0.01.  If
			     ${CONFIG_VERSION_FILE} does not exist or is empty, the version number
			     of 1.0 will be applied.
    -c|--crs-check <type>
			     Common repo scripts check will, depending on the type provided, 
			     will compare the version of the config repo's current copy of the 
			     common repo scripts to the latest version.

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



perform_crs_check() {
    local type=${1}

    local update="n"
    
    if [ ${type} = "skip" ]; then
	return 0
    fi

    if [ ! -d ${CRS_SRC_DIR} ]; then
	>2& echo "Common repo script directory \"${CRS_SRC_DIR}\" not found.  Cannot perform crs " \
		 "check."
	return 1
    fi

    if [ ! -d ${CRS_DIR} ]; then
	echo "Repo does not have a copy of the common repo scripts directory.  Will create a copy."
	echo "Will copy from \"${CRS_SRC_DIR}\" to \".\""
	if rsync -par ${CRS_SRC_DIR} .; then
	    echo "Common repo scripts directory copy created."
	    return 0
	else
	    echo "Error creating common repo script directory copy."
	    return 1
	fi
    else
        CRS_SRC_VERSION=$(cat ${CRS_SRC_DIR}/${CRS_VERSION_FILE})
	CRS_VERSION=$(cat ${CRS_DIR}/${CRS_VERSION_FILE})
	echo CRS_SRC_VERSION  ${CRS_SRC_VERSION}
	echo CRS_VERSION ${CRS_VERSION}
	if [[ ${CRS_SRC_VERSION} > ${CRS_VERSION} ]]; then
	    echo "Common repo scripts src version ${CRS_SRC_VERSION} is greater than" \
		 "that of the copy found in this repo (version ${CRS_VERSION})."
	    
	    case ${type} in
		check)
		    echo "Provide --crs-check-type type \"update\" to update"
		    ;;
		update)
		    echo " Will update."
		    update="y"
		    ;;
		prompt)
		    local response="u"
		    local responseRegEx="^[yn]$"
		    while [[ ! "${response}" =~ ${responseRegEx} ]]; do
			echo -n "Update copy of common repo scripts? (y/n): "
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
		cp -p ${CRS_DIR}/${CRS_VERSION_FILE} ${CRS_DIR}/${CRS_PRIOR_VERSION_FILE} 
		if rsync -par ${CRS_SRC_DIR} .; then
		    echo "Update complete"
		else
		    echo "Update failed"
		fi
	    fi
	fi
    fi
    
}

REPO_DIR=$(git rev-parse --show-toplevel)
BASE_DIR="$(realpath $(get_script_dir)/..)"
CRS_SRC_DIR="${BASE_DIR}/common_repo_scripts"
CRS_DIR="common_repo_scripts"
CRS_VERSION_FILE="VERSION"
CRS_PRIOR_VERSION_FILE="PRIOR_VERSION"
CONFIG_VERSION_FILE="CONFIG_VERSION"
CONFIG_PRIOR_VERSION_FILE="CONFIG_PRIOR_VERSION"

cd ${REPO_DIR}
#################
# Source Script CFG file
SCRIPT_CFG_FILE="${BASE_DIR}/cfg/$(basename ${0} .sh).cfg"
##################

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
    # if [ -z ${CRS_LOCAL_REPO} ]; then
    # 	>&2 echo "Script cfg file, \"${SCRIPT_CFG_FILE}\", did not contain a" \
    # 	    "declaration for CRS_REPO, the separate source repo" \
    # 	    "for the scripts included with the CONFIG_REPO distribution. Exiting."
    # 	exit 1
    # fi
    # if [ -z ${CRS_GITHUB} ]; then
    # 	>&2 echo "Script cfg file, \"${SCRIPT_CFG_FILE}\", did not contain a" \
    # 	    "declaration for CRS_GITHUB, the separate repo" \
    # 	    "for the common scripts included with the CONFIG_REPO distribution. "\
    # 	    "Exiting."
    # 	exit 1
    # fi
fi

if [ $# -lt 1 ]; then
   usage
   exit 1
fi

# config_repo_name=${1}

# if [ ${config_repo_name} = "." ]; then
#     config_repo_name=$(basename $(realpath $(pwd)))
# fi

# repo_dir=${CONFIG_REPO_DIR}/${config_repo_name}
# if cd ${repo_dir}; then
#     echo Changed dir to ${repo_dir} "("$(pwd)")"
# else
#     echo Could not change dir to git config repo ${repo_dir}.  Exiting....
#     exit -1
# fi
crs_check_type="update"
while [[ $# -gt 0 ]]; do
    case $1 in
	-c|--crs-check)
	    crs_check_type=$2
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

perform_crs_check ${crs_check_type}

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




