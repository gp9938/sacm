#!/bin/bash

VALID_COMMANDS=( "restart" "start" "stop" "update_and_restart")
containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

usage() {
    cat <<EOF
    $0 <action_file>
    
    action_file Actions file
EOF
}

isValidCommand() {
    local command=${1}
    if (containsElement ${command} ${VALID_COMMANDS[@]}); then
	echo "${command} is a valid command"
	return 0
    else
	echo "${command} is NOT valid"
	return 1
    fi
}

restart() {
    echo "restart command function called"
    stop()
    update()
    start()
}

start() {
    echo "start command function called"
    ./bin/start.sh
}

stop() {
    echo "stop command function called"
    ./bin/stop.sh
}

update() {
    echo "update command function called"
    git pull
}

update_and_restart() {
    echo "update_and_restart command function called"
    stop()
    
}

set +e #otherwise the script will exit on error

if [ $# != 1 ]; then
    usage()
fi

action_file=${1}

# open file
action_file_fd=3
exec ${action_file_fd} <> ${action_file}
lineNo=1
while read -r -a line -u ${action_file_fd}; do
    echo "${lineNo}: ${line[0]} ${line[1]}"
    if [ ! -z ${line[0]} ]; then # local repo (i.e. app)
	repo=${CLIENT_CONFIG_REPO_BASEDIR}/${line[0]}
	if [ -d ${repo} ]; then
	    cd ${repo}
	    if [ ! -z ${line[1]} ]; then # command for local repo
		if (isValidCommand ${line[1]}); then
		    eval ${line[1]}
		else
		    echo "Invalid command \${line[1]}\" for repo \"${line[0]}\" on line ${lineNo}.  Ignored."
		fi
		
	    fi
	else
	    echo "Invalid repo (app) \"${line[0]}\" specified on line ${lineNo}.  Ignored."
	fi
    fi
    ((++lineNo))
done

