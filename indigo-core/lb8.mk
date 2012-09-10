# Copyright (c) Big Switch Networks 2011 and Stanford University, 2010
#
# Makefile fragment for Quanta lb8 platform

export PLAT=lb8
include quanta.mk

PLAT_NAME=Pronto 3780
PLAT_TAG=pronto-3780

export ARCH=powerpc

export STANFORD_LB8=1
export QUANTA_LB8=1

# From quanta build
export T23XSEC2=0

CFG_CFLAGS += -DSTANFORD_LB8 -DQUANTA_LB8
BUILD_STRING += Stanford-LB8.
HW_LIB_NAME = stanford-lb8

PLATFORM_ROOT=${TOP_LEVEL_DIR}/indigo-lb8
export LINUX_ROOT=${PLATFORM_ROOT}/linux-2.6.27
LINUX_VERSION=2.6.27


UBOOT_DIR=${PLATFORM_ROOT}/u-boot-1.3.0

RAMDISK_BLOCKS=40960
#BUSYBOX_DIR=${PLATFORM_ROOT}/busybox-1.13.3

RELEASE_FILES+=${PRODUCT_DIR}/device-tree.dtb
