#!/bin/bash
#
# Empty the actions file and git commit the change
#

usage() {
    cat <<EOF
    $0 <action_file>
    
    action_file Actions file
EOF
}

if [ $# != 1 ]; then
    usage()
fi


action_file=${1}

cat /dev/null > ${action_file}
git add ${action_file}
git commit -m "${HOSTNAME} cl empties action"
git push

