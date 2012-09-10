# Copyright (c) Big Switch Networks 2011 and Stanford University, 2010
#
# Makefile fragment for Quanta lb9a platform

export PLAT=lb9a
include quanta.mk

PLAT_NAME=Pronto 3290
PLAT_TAG=pronto-3290

export ARCH=powerpc

export STANFORD_LB9A=1
export QUANTA_LB9A=1

CFG_CFLAGS += -DSTANFORD_LB9A -DQUANTA_LB9A
BUILD_STRING += Stanford-LB9A.
HW_LIB_NAME = stanford-lb9a

PLATFORM_ROOT=${TOP_LEVEL_DIR}/indigo-lb9a
export LINUX_ROOT=${PLATFORM_ROOT}/linux-2.6.27
LINUX_VERSION=2.6.27


UBOOT_DIR=${PLATFORM_ROOT}/u-boot-1.3.0

RAMDISK_BLOCKS=40960
#BUSYBOX_DIR=${PLATFORM_ROOT}/busybox-1.13.3

# Fan daemon target
fand: quanta-drivers
	rm -f ${PLATFORM_ROOTFS_TEMPLATE}/sbin/fand
	rm -f ${PLATFORM_ROOTFS_TEMPLATE}/sbin/setfan
	cp ${PLATFORM_ROOT}/quanta-drivers/fand ${PLATFORM_ROOTFS_TEMPLATE}/sbin
	cd ${PLATFORM_ROOTFS_TEMPLATE}/sbin && ln -s fand setfan && chmod +x fand setfan

.PHONY: fand
