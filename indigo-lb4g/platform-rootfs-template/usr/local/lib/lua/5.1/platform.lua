-- Copyright 2011 Big Switch Networks
--
-- Platform specific code for UI

Platform = Platform or {}

Platform.hw_name = "Pronto 3240"

-- This should be the same as the identifier used in the Makefile
Platform.plat = "lb4g"

-- Config storage information
Platform.cfg_use_sfs = 1
Platform.cfg_filename = "/local/sfs/sysenv"
Platform.cfg_history_dir = "/local/sfs/cfg_history/" -- Dir for storing config history
Platform.sfs_parent_dir = "/local"
Platform.log_dir = "/local/logs"

-- Management interface
Platform.mgmt_if = "eth0"
Platform.mgmt_if_allowed = {"eth0", "eth1"}
