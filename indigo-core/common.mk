# Copyright (c) Big Switch Networks, 2011 and Stanford University, 2010
#
# Common Indigo definitions and targets
#
# This file is normally included by the platform specific make file.
#
# Note that multiple very different platforms can be built from
# this make system, so:
# TODO:  Verify that all targets satisfy one of the following:
#    1. Make clean as prereq
#    2. Uses platform specific build directory

include base.mk
-include iods.mk

################################################################
#
# Configuration flags for build
#
################################################################

export BCM_HW_PLAT = 1
export OPENFLOW_BUILD = 1
export OF_HW_PLAT=1

CFG_CFLAGS := -DOF_HW_PLAT -DBCM_HW_PLAT ${CMDLINE_CFLAGS}

# By default, include watchdog support
ifndef NOWATCHDOG
CFG_CFLAGS += -DWATCHDOG_SUPPORT
endif

ifdef SPROF
CFG_CFLAGS += -DSPROF_SUPPORT
endif

################################################################
################################################################
#
# BELOW THIS, REFERENCES MAY BE PLATFORM SPECIFIC
#
################################################################
################################################################

################################################################
#
# Locations for build process
#
################################################################

PRODUCT_DIR=${CORE_DIR}/build-images/${BLD_EXT}

################################################################
#
# Default defines for key variables
#
################################################################

PLATFORM_ROOT=${TOP_LEVEL_DIR}/indigo-${PLAT}
PLATFORM_ROOTFS_TEMPLATE=${PLATFORM_ROOT}/platform-rootfs-template
TARGET_ROOTFS=${TMP_FILES_DIR}/rootfs-${BLD_EXT}
# TARGET_ROOTFS_IMAGE name is platform specific

ifdef RELEASE_NAME
VERSION_NAME:=${RELEASE_NAME}
else
VERSION_NAME:=Indigo build $(shell date +"%F %R")${target_suffix}
endif

ifdef IODS_BUILD
VERSION_NAME:=${VERSION_NAME}-iods
endif

VERSION_NAME:=$(shell echo "${VERSION_NAME}" | sed -e 's: :_:g')

VERSION_FILE=${TARGET_ROOTFS}/etc/indigo-version

################################################################
#
# Label for identifying build
#
################################################################

BLD_EXT:=${PLAT}

ifdef BCM_BINARY_RELEASE
BLD_EXT:=${BLD_EXT}-binrel
BUILD_STRING +=Binary release.
endif

ifdef NO_BCM_DEBUG
BLD_EXT:=${BLD_EXT}-nodbg
endif

export target_suffix=-${BLD_EXT}

################################################################
#
# Compile setup
#
################################################################
export ARCH
export ARCH_PREFIX=ppc_85xx
export LINUX_ARCH_DIR=${ELDK_DIR}/${ARCH_PREFIX}

export CROSS_COMPILE=ppc_85xx-
export CROSS_COMPILE_PATH=${ELDK_DIR}/usr

# Update path with cross compile path
export CFG_CFLAGS

# Default cross compiler prefix for target passed to config
CROSS_NAME=powerpc-linux


################################################################
#
# OpenFlow compilation defines
#
################################################################

OF_CFG_FLAGS = --host=${CROSS_NAME}
OF_CFG_FLAGS += --enable-hw-lib=${PLAT}
OF_HW_LIB = lib${HW_LIB_NAME}.a

BUILD_STRING +=User mode.

################################################################
#
# Other component platform specific defines
#
################################################################

export LUA_INSTALL=${TARGET_ROOTFS}

################################################################
#
# Linux defines and targets
#
################################################################

export LINUX_INCLUDE=${LINUX_ROOT}/include

# Annoying redundant names for linux root
export KERNELDIR=${LINUX_ROOT}
export KERNDIR=${LINUX_ROOT}

# This links the Linux source dir to the tool chain
ifndef ELDK_LINUX_LINK
tool-env-init:
	sudo rm -f ${ELDK_LINUX_LINK}
	sudo ln -s ${LINUX_ROOT} ${ELDK_LINUX_LINK}
else
tool-env-init: eldk_linux_link-not-defined
	@echo "ELDK_LINUX_LINK is not defined"
endif

# Linux bootstrap config, platform specific
linux-config: tool-env-init
	echo "Configuring Linux kernel"
	${LINUX_CONFIG_COMMAND}

# Target to build kernel
ifdef QUICK_BUILD
linux-kernel: linux-config
	echo "Quick Build: Not building Linux kernel"
else
linux-kernel: linux-config
	echo "Building Linux kernel"
	make -C ${LINUX_ROOT} -j4
endif

# Target to ensure Linux dir is prepared for other builds that use it
linux-prep: linux-config
	echo "Prep Linux"
	make -C ${LINUX_ROOT} prepare

uboot: ${PRODUCT_DIR}/u-boot.bin
${PRODUCT_DIR}/u-boot.bin: ${PRODUCT_DIR}
	make -C ${UBOOT_DIR}
	cp -f ${UBOOT_DIR}/u-boot.bin ${PRODUCT_DIR}/

# Expect kernel to be prebuilt.  Explicit target is below.
LINUX_KERNEL_IMAGE=${LINUX_ROOT}/arch/${ARCH}/boot/uImage
${PRODUCT_DIR}/uImage: ${PRODUCT_DIR}
	cp ${LINUX_KERNEL_IMAGE} ${PRODUCT_DIR}/uImage

# And in case you want to make them clean....

uboot-clean:
	make -C ${UBOOT_DIR} clean
	find ${UBOOT_DIR} -type f -name '.depend' -print | xargs rm -f
	rm -f ${UBOOT_DIR}/System.map ${UBOOT_DIR}/u-boot*

linux-clean:
	make -C ${LINUX_ROOT} clean
	rm -f ${PRODUCT_DIR}/uImage

################################################################
#
# Administrative targets
#
################################################################

copy-to-latest:
	mkdir -p ${MOUNT_DIR}
	rm -f ${LATEST_IMAGE}
	ln -s ${TARGET_ROOTFS_IMAGE} ${LATEST_IMAGE}

${PRODUCT_DIR}:
	mkdir -p ${PRODUCT_DIR}

# Copy HTML files to the local host for debugging
#host-html: html-files
#	cp -a ${INIDGO_ROOTFS_TEMPLATE}/usr/local/httpd/* /local/httpd
#	cp -a ${TARGET_ROOTFS}/usr/local/httpd/* /local/httpd

################################################################
#
# OpenFlow targets (other than ofswd)
#
################################################################

export OF_CFG_FLAGS += CFLAGS="${CFG_CFLAGS}"

OF_BLD_DIR = ${CORE_DIR}/of-bld/${BLD_EXT}
export OF_SRC_DIR = ${CORE_DIR}/openflow

# OpenFlow configuration
${OF_BLD_DIR}/Makefile: openflow/acinclude.m4 openflow/configure.ac \
		linux-kernel cmdsrv
	mkdir -p ${OF_BLD_DIR}
	cp build-files/openflow/automake.mk openflow/debian
	(cd openflow && ./boot.sh)
	(cd ${OF_BLD_DIR} && ${OF_SRC_DIR}/configure ${OF_CFG_FLAGS})

# For IODS build, must specify specific OF targets; otherwise build all
ifdef IODS_BUILD
OPENFLOW_TARGETS=secchan/ofprotocol utilities/dpctl
endif

# TODO: Fix for IODS; not ref'd there now.
OF_IND_VER_FILE=${OF_SRC_DIR}/include/of_indigo_version.h
# Openflow executable related
openflow: target-rootfs-init ${OF_BLD_DIR}/Makefile cmdsrv
	echo "#define INDIGO_REL_NAME \"${VERSION_NAME}\"" > ${OF_IND_VER_FILE}
	echo "#define INDIGO_MFR_DESC \"Indigo OpenFlow from Big Switch Networks\"" >> ${OF_IND_VER_FILE}
	make -C ${OF_BLD_DIR} ${OPENFLOW_TARGETS}
	cp ${OF_BLD_DIR}/secchan/ofprotocol \
		${OF_BLD_DIR}/secchan/ofprotocol.unstripped
	cp ${OF_BLD_DIR}/utilities/dpctl \
		${OF_BLD_DIR}/utilities/dpctl.unstripped
	$(CROSS_COMPILE)strip ${OF_BLD_DIR}/secchan/ofprotocol
	$(CROSS_COMPILE)strip ${OF_BLD_DIR}/utilities/dpctl
	cp ${OF_BLD_DIR}/secchan/ofprotocol ${TARGET_ROOTFS}/sbin
	cp ${OF_BLD_DIR}/utilities/dpctl ${TARGET_ROOTFS}/sbin

openflow-clean:
	rm -rf ${OF_BLD_DIR}

################################################################
#
# Additional Product Build Definitions
#
# These are here for convenience; the primary build does not
# depend on these.
#
# In general, INSTALL_DIR should be ${TARGET_ROOTFS}
#
################################################################

COMMON_PRODUCTS=cmdsrv dropbear

# FIXME:  Should update all binaries in platform template with each release
ifndef QUICK_BUILD
COMMON_PRODUCTS+=lua haserl
ifndef NO_BB_BLD
COMMON_PRODUCTS+=busybox
endif
endif

# Current requires busybox directory be pre-configured 
busybox-clean:
	make -C ${BUSYBOX_DIR} clean

# FIXME:  Shouldn't depend on clean
busybox: busybox-clean target-rootfs-init
	make -C ${BUSYBOX_DIR} install
	cp -a ${BUSYBOX_DIR}/_install/* ${TARGET_ROOTFS}

DROPBEAR_ARCH=${ARCH}
# Current requires dropbear directory be pre-configured 
DROPBEAR_CONFIG_CMDLINE=${DROPBEAR_DIR}/configure --prefix=${TARGET_ROOTFS} \
   --host=${DROPBEAR_ARCH}-linux --disable-lastlog --disable-loginfunc \
   --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx

# FIXME:  Should be able to do build specific makes for dropbear, haserl etc
DROPBEAR_MAKE_CMDLINE=STATIC=1 PROGRAMS="dropbear dropbearkey scp" strip
dropbear: target-rootfs-init
	mkdir -p ${DROPBEAR_MAKE_DIR}
	(cd ${DROPBEAR_MAKE_DIR} && ${DROPBEAR_CONFIG_CMDLINE})
	make -C ${DROPBEAR_MAKE_DIR} PROGRAMS="${DROPBEAR_PROGRAMS}"
	sudo make -C ${DROPBEAR_MAKE_DIR} install

dropbear-clean:
	rm -rf ${DROPBEAR_MAKE_DIR}

# Current requires lua directory be pre-configured 
lua: target-rootfs-init
	make -C ${LUA_SOCKET_DIR} clean
	make -C ${LUA_SOCKET_DIR} install
	make -C ${LUA_DIR} clean
	make -C ${LUA_DIR} linux
	make -C ${LUA_DIR} install
	(cd ${TARGET_ROOTFS}/lib && ln -s liblua.a liblua5.1.a)

haserl: lua
	mkdir -p ${HASERL_MAKE_DIR}
	(cd ${HASERL_MAKE_DIR} && ${HASERL_DIR}/configure --with-lua=${TARGET_ROOTFS}/lib --with-lua-headers=${TARGET_ROOTFS}/include --enable-luashell --enable-subshell=/bin/sh --libdir=${TARGET_ROOTFS}/lib --prefix=${TARGET_ROOTFS} --host=ppc_85xx)
	make -C ${HASERL_MAKE_DIR} install
	cp ${HASERL_EXE} ${TARGET_ROOTFS}/bin

# UI build is not separated per-platform, so always clean
ui: ui-clean haserl lua cmdsrv

ui-clean: cmdsrv-clean busybox-clean dropbear-clean
	make -C ${LUA_DIR} clean
	make -C ${LUA_SOCKET_DIR} clean
	make -C ${HASERL_DIR} clean

# This generates all the HTML pages
HTML_VERSION=${VERSION_NAME}: ${BUILD_STRING}
html-files: target-rootfs-init
	(cd ${TARGET_ROOTFS}/usr/local/httpd && \
		${CORE_DIR}/tools/html_gen.lua "${PLAT_NAME}" "${HTML_VERSION}")


################################################################
#
# Command server provides a limited REST interface into ofswd
#
################################################################

# For IODS build, must specify cmdsrv targets; otherwise build all
ifdef IODS_BUILD
CMDSRV_TARGETS=cmdsrv_client.a
endif

cmdsrv: cmdsrv-clean
	make -C ${CMDSRV_DIR} ${CMDSRV_TARGETS}

cmdsrv-clean:
	make -C ${CMDSRV_DIR} clean


################################################################
#
# Common root FS requirements
#
################################################################

rootfs-common: target-rootfs-init openflow ${BINARY_FILES_TARGET} \
		${COMMON_PRODUCTS}
	@echo "Root FS common pre-reqs complete: ${COMMON_PRODUCTS}"


################################################################
#
# Various administrative targets
#
################################################################

md5: 
	md5sum ${FLASH_IMAGE}

clean: openflow-clean ${DRIVERS_CLEAN} ui-clean

export NFS_DIR = /var/exports/${BLD_EXT}${NFS_EXT}

# Remote TFTP directory
#TFTP_DIR=oberon:/var/tftpboot
#TFTP_DIR=its1:/var/tftpboot

ifdef TFTP_DIR
tftp-rfs:
	scp ${FLASH_IMAGE} ${TFTP_DIR}
else
tftp-rfs:
	echo "no remote tftp server"
endif

nfs: ${TARGET_ROOTFS}
	echo "Building nfs for ${BLD_EXT} to ${NFS_DIR}"
	sudo mkdir -p ${NFS_DIR}
	sudo cp -a ${TARGET_ROOTFS}/* ${NFS_DIR}/
	sudo chmod -cR 777 ${NFS_DIR}
	cd /var/exports && sudo tar czf ${BLD_EXT}.tgz ${BLD_EXT}

show:
	@echo "PLAT:               ${PLAT}"
	@echo "ARCH:               ${ARCH}"
	@echo "BLD_EXT:            ${BLD_EXT}"
	@echo "CORE_DIR:           ${CORE_DIR}"
	@echo "TOP_LEVEL_DIR:      ${TOP_LEVEL_DIR}"
	@echo "PLATFORM_ROOT:      ${PLATFORM_ROOT}"
	@echo "CROSS_COMPILE:      ${CROSS_COMPILE}"
	@echo "LINUX_ROOT:         ${LINUX_ROOT}"
	@echo "NFS_DIR:            ${NFS_DIR}"
	@echo "PATH:               ${PATH}"
	@echo "PLAT_NAME:          ${PLAT_NAME}"
	@echo "SDK:                ${SDK}"
	@echo "VERSION_NAME:       ${VERSION_NAME}"
	@echo "target_suffix:      ${target_suffix}"
	@echo "PRODUCT_DIR:        ${PRODUCT_DIR}"
	@echo "ELDK_DIR:           ${ELDK_DIR}"

# More verbose list of variables
allvars: show
	@echo "LINUX_KERNEL_IMAGE: ${LINUX_KERNEL_IMAGE}"
	@echo "BCM_BUILD_DIR:      ${BCM_BUILD_DIR}"
	@echo "BCM_LIB_DIR:        ${BCM_LIB_DIR}"
	@echo "BUILD_STRING:       ${BUILD_STRING}"
	@echo "CFG_CFLAGS:         ${CFG_CFLAGS}"
	@echo "OF_CFG_FLAGS:       ${OF_CFG_FLAGS}"
	@echo "OF_HW_LIB:          ${OF_HW_LIB}"
	@echo "COMMON_ROOTFS_TEMPLATE:   ${COMMON_ROOTFS_TEMPLATE}"
	@echo "PRONTO_ROOTFS_TEMPLATE:   ${PRONTO_ROOTFS_TEMPLATE}"
	@echo "PLATFORM_ROOTFS_TEMPLATE: ${PLATFORM_ROOTFS_TEMPLATE}"
	@echo "TARGET_ROOTFS:      ${TARGET_ROOTFS}"
	@echo "SHELL:              ${SHELL}"
	@echo "UBOOT_DIR:          ${UBOOT_DIR}"
	@echo "UI_DIR:             ${UI_DIR}"
	@echo "LUA_DIR:            ${LUA_DIR}"
	@echo "PLATFORM_DRIVERS:   ${PLATFORM_DRIVERS}"
	@echo "IODS_BUILD:         ${IODS_BUILD}"
	@echo "IODS_BINARY_ONLY_FILES:   ${NON_IODS_BINARY_FILES}"
	@echo "TFTP_DIR:           ${TFTP_DIR}"
	@echo "COMMON_PRODUCTS:    ${COMMON_PRODUCTS}"
	export

.PHONY: all rootfs show all-vars busybox lua haserl dropbear dropbear-clean \
	target-rootfs-init nfs cmdsrv cmdsrv-clean ${DRIVERS_CLEAN} \
	of-bcm-libs openflow openflow-libs bcm-sdk uboot sfs clean bcm-clean \
	copy-to-latest openflow-clean tftp-rfs bde \
	host-html html-files ui-clean ui dev linux-prep linux-config \
	busybox-clean iods-platform rootfs-common

