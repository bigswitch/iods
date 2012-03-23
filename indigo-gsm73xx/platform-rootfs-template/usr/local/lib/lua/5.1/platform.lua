-- Copyright 2011 Big Switch Networks
--
-- Platform specific code for UI

Platform = Platform or {}

Platform.hw_name = "Netgear GSM73xx"

-- This should be the same as the identifier used in the Makefile
Platform.plat = "gsm73xx"

-- Config storage information
Platform.cfg_use_sfs = 1
Platform.cfg_filename = "/local/sfs/sysenv"
-- Dir for storing config history
Platform.cfg_history_dir = "/local/sfs/cfg_history/"
Platform.sfs_parent_dir = "/local"
Platform.log_dir = "/local/logs"

-- Management IP
Platform.mgmt_if = "tap0"
Platform.mgmt_if_allowed = {"tap0"}
