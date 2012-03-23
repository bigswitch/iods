-- Copyright 2011 Big Switch Networks
--
-- Platform specific code for UI

Platform = Platform or {}

Platform.hw_name = "Pronto 3780"

-- This should be the same as the identifier used in the Makefile
Platform.plat = "lb8"

-- Config storage information
Platform.cfg_filename = "/cf_card/local/sysenv"
Platform.cfg_history_dir = "/cf_card/local/cfg_history/" -- Dir for config history

Platform.log_dir = "/cf_card/local/logs"

-- Management interface
Platform.mgmt_if = "eth0"
Platform.mgmt_if_allowed = {"eth0", "eth1"}
