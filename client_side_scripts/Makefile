#
# Makefile for sacm client-side self-installer which is more of a boostrap for the client
# side
SHELL := /bin/bash
include ./CLIENT_SCRIPT_DEFAULTS.cfg 
.ONESHELL:

.PHONY: all setup_env 
.SILENT: $(SELF_INSTALLER_TARGET)

INSTALL_FILES := crontab_installer.sh install_cron_entry.sh uninstall_cron_entry.sh \
		install.sh CLIENT_SCRIPT_DEFAULTS.cfg self_install_stub.sh
SUPPORT_SCRIPTS :=  ../shared_scripts
TMP_DIR :=  "/tmp/MakefileTMP_"$$PPID
INSTALLER_DATA_DIR := $(TMP_DIR)"/installer"
INSTALLER_DATA_TAR_FILE := $(INSTALLER_DATA_DIR)"/installer_data.tgz"
SELF_INSTALLER_TARGET := sacm_installer.sh

all: setup_env $(SELF_INSTALLER_TARGET)

setup_env:



$(SELF_INSTALLER_TARGET): $(INSTALL_FILES) $(SUPPORT_SCRIPTS)
	@echo Making $(SELF_INSTALLER_TARGET)
	function cleanup {
	    if [ -d ${TMP_DIR} ]; then
		rm -rf ${TMP_DIR}
	    fi
	}
	@trap cleanup EXIT
	@echo Create temp install data dir ${INSTALLER_DATA_DIR}
	@mkdir -p ${INSTALLER_DATA_DIR}
	@echo Copy files to temp install data dir
	@cp --preserve=all ${INSTALL_FILES} ${INSTALLER_DATA_DIR}
	@echo Copy support scripts to temp install data dir
	@rsync -par ${SUPPORT_SCRIPTS} ${INSTALLER_DATA_DIR}
	@echo Create tar file
	@tar -C ${INSTALLER_DATA_DIR} -cvzf ${INSTALLER_DATA_TAR_FILE} .
	@echo Create self installer
	@cat self_install_stub.sh $(INSTALLER_DATA_TAR_FILE) > $(SELF_INSTALLER_TARGET)
	@chmod 755 $(SELF_INSTALLER_TARGET)
	@echo Created installer $(SELF_INSTALLER_TARGET)
	@echo Done
	@cleanup
