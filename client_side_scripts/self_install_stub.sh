#!/bin/bash
TMP_DIR="/var/tmp/$(basename $0 .sh)$$"
INSTALL_SCRIPT="${TMP_DIR}/install.sh"

cleanup() {
    if [ -d ${TMP_DIR} ]; then
	rm -rf ${TMP_DIR}
    fi
}

mkdir ${TMP_DIR}

sed '0,/^#EOF#$/d' $0 | tar -xzC ${TMP_DIR} 
if [ -x ${INSTALL_SCRIPT} ]; then
    ${INSTALL_SCRIPT}
else
    echo "Could not find ${INSTALL_SCRIPT} within installer. Exiting..." >&2
    exit 1
fi
exit 0
#EOF#
