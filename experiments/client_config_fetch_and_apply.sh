#!/bin/bash

#
# need a host repo dir
#
REMOTE_GIT_BASE_URL="git://wanda.local/"
CLIENT_CONFIG_REPO_BASEDIR="/root/git-config-repos"
CLIENT_CONFIG_REPO_NAME=${HOSTNAME}
CLIENT_CONFIG_REPO_DIR=${HOST_REPO_BASEDIR}/${CLIENT_CONFIG_REPO_NAME}

if [ ! -d ${CLIENT_CONFIG_REPO_BASEDIR} ]; then
    echo Could not find config repo base dir ${CLIENT_CONFIG_REPO_BASEDIR}.  This \
	 directory must exist.  Exiting...
    exit -1
fi

cd ${CLIENT_CONFIG_REPO_BASEDIR}

if [ ! -d ${CLIENT_CONFIG_REPO_NAME} ]; then
    git clone ${REMOTE_GIT_BASE_URL}/${CLIENT_CONFIG_REPO_NAME} --recurse-submodules=yes


    
    git submodule foreach '(bin/run.sh) &'
fi

#
# How to best disable an app and have it stop?
#
