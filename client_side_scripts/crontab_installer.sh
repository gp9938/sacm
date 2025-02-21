#!/bin/bash

# Return the directory from which a script was run.   If the script
# is reached via symlink,this script will return the directory of the
# symlink because it uses "realpath -s". Function get_real_script_dir
# drops the -s and will therefore return the directory of the
# script file rather than the symlink.
bootstrap_get_script_dir() {
    echo $(dirname $(realpath -s $0))
}

COMMON_SH="$(bootstrap_get_script_dir)/shared_scripts/common.sh"
if [ -f ${COMMON_SH} ]; then
    . ${COMMON_SH}
else
    echo "Cannot load common.sh. Exiting..." >&2
    exit 1
fi

INSTALL_SCRIPT_NAME="install_cron_entry.sh"
UNINSTALL_SCRIPT_NAME="uninstall_cron_entry.sh"

TMP_CRONTAB="/tmp/crontab_$$"
TMP_CRONTAB_2="${TMP_CRONTAB}_2"
COMMENT="# automatically added for sacm client_daemon -- do not modify line"
DAEMON_SCRIPT="$(get_script_dir)/client_daemon.sh"
CRONTAB_LINE="@reboot ${DAEMON_SCRIPT} ${COMMENT}"

CRONCHECK_REGEX="${COMMENT}"'$'
crontab -l 2>/dev/null > ${TMP_CRONTAB}

if [ $(basename $0) = ${INSTALL_SCRIPT_NAME} ]; then
    if grep -Eq "${CRONCHECK_REGEX}" ${TMP_CRONTAB}; then
	echo "Found existing cron entry for sacm client_daemon in crontab. Will not add." >&2
    else
	echo ${CRONTAB_LINE} >> ${TMP_CRONTAB}
	crontab ${TMP_CRONTAB}
    fi
elif [ $(basename $0) = ${UNINSTALL_SCRIPT_NAME} ]; then
    if grep -Eq "${CRONCHECK_REGEX}" ${TMP_CRONTAB}; then
	grep -Ev "${CRONCHECK_REGEX}" ${TMP_CRONTAB} > ${TMP_CRONTAB_2}
	crontab ${TMP_CRONTAB_2}
    else
	echo "Cron entry for sacm client_daemon not found in crontab.  Cannot uninstall"
	echo ${CRONTAB_LINE} >> ${TMP_CRONTAB}
	crontab ${TMP_CRONTAB}
    fi
else
    echo "Script started with unknown name $(basename $0), cannot continue." >&2
    exit 1
fi
    
rm -f ${TMP_CRONTAB}
