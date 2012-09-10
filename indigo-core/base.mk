# Copyright (c) Big Switch Networks, 2011
#
# Base make defines.  No dependencies
#

################################################################
#
# THIS PORTION OF THE FILE IS NOT PLATFORM SPECIFIC
# Makefile may refer to things here
#
################################################################

# High level defines
ifndef TOP_LEVEL_DIR
$(error "Need TOP_LEVEL_DIR defined; source build-files/env[.tcsh]")
endif

ifndef CORE_DIR
$(error "Need CORE_DIR defined; source build-files/env[.tcsh]")
endif

ifndef TOOLS_DIR
$(error "Need TOOLS_DIR defined; source build-files/env[.tcsh]")
endif

# Try to include IDOS or full source specific build info
-include fullsrc.mk

SUPPORTED_PLATFORMS=lb9a gsm73xx lb8 lb4g t2ref
CLEAN_TARGETS=$(addsuffix -clean,${SUPPORTED_PLATFORMS})

MOUNT_DIR=rootfs-mounts
LATEST_IMAGE=${MOUNT_DIR}/rootfs-image-latest

TMP_FILES_DIR=${CORE_DIR}/tmp-files
BUILD_FILES=${CORE_DIR}/build-files
CONFIG_DIR=${CORE_DIR}/config-files

# High level common components
export CMDSRV_DIR=${TOP_LEVEL_DIR}/cmdsrv
export UI_DIR=${TOP_LEVEL_DIR}/indigo-ui

# Needed for proper lua installation; but these are generally prebuilt
export LUA_DIR=${UI_DIR}/lua-5.1.4
export LUA_EXEC=${LUA_DIR}/src/lua
export LUA_SOCKET_DIR=${UI_DIR}/luasocket-2.0.2

export HASERL_DIR=${UI_DIR}/haserl-0.9.27
export HASERL_MAKE_DIR=${TMP_FILES_DIR}/haserl-${BLD_EXT}
export HASERL_EXE=${HASERL_MAKE_DIR}/src/haserl

# Fixme: Referenced in final ofswd link
export JSON_DIR=${CMDSRV_DIR}/json-c-0.9/ppc

# Default locations for source in core
DROPBEAR_DIR=${CORE_DIR}/dropbear-0.52
DROPBEAR_MAKE_DIR=${TMP_FILES_DIR}/dropbear-${BLD_EXT}
#DROPBEAR_MAKE_DIR=${DROPBEAR_DIR}
DROPBEAR_PROGRAMS=dropbear dbclient dropbearkey dropbearconvert scp
BUSYBOX_DIR=${CORE_DIR}/busybox-1.20.2

PRONTO_ROOTFS_TEMPLATE=${CORE_DIR}/pronto-rootfs-template
COMMON_ROOTFS_TEMPLATE=${CORE_DIR}/common-rootfs-template
