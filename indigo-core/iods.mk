# Copyright (c) Big Switch Networks, 2011
#
# IODS definitions
#
# This file generated for IODS build

IODS_BUILD=1
RELEASE_NAME=2012.03.19
IODS_BIN_FILENAME=iods-${RELEASE_NAME}-${PLAT}.tgz
IODS_BIN_ORIGIN=${TOP_LEVEL_DIR}/${IODS_BIN_FILENAME}

IODS_BIN_CHECK=$(wildcard ${IODS_BIN_ORIGIN})

# Test if IODS_BIN_CHECK is present and die if not
ifeq (${IODS_BIN_CHECK},)
IODS_ERR_MSG=The file ${IODS_BIN_ORIGIN} containing the core Indigo \
exectutables was not found.  It must be downloaded separately for an \
IODS build.  Please see the Indigo section of http://openflowhub.org
$(error "${IODS_ERR_MSG}")
endif

# Target for binary file installation under IODS.
BINARY_FILES_TARGET=iods-binary-install
iods-binary-install: target-rootfs-init
	cd ${TARGET_ROOTFS} && tar xzf ${IODS_BIN_ORIGIN}
