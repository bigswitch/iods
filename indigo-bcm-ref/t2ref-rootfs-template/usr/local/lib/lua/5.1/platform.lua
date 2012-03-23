-- Copyright 2011 Big Switch Networks
--
-- Platform specific code for UI
Platform = Platform or {}

Platform.hw_name = "Broadcom 56634 Reference Design"

-- This should be the same as the identifier used in the Makefile
Platform.plat = "t2ref"

-- Config storage information
Platform.cfg_filename = "/local/sysenv"
Platform.cfg_history_dir = "/local/cfg_history/" -- Dir for config history

Platform.log_dir = "/local/logs"

-- Management interface
Platform.mgmt_if = "eth0"
Platform.mgmt_if_allowed = {"eth0", "eth1"}

