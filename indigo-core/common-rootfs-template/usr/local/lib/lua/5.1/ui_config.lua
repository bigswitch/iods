-- Copyright (c) Big Switch Networks
-- ui_config.lua
-- Configuration routines for CLI and Web UI

-- General ui_ Lua conventions
--     ui_dbg_verb, error, warn, info are vectors with printf semantics;
--     See dbg_lvl_set in ui_utils.lua
--

-- Currently all config vars are written to sysenv; this could
-- be broken out to sysenv and other config vars

-- Configurations are stamped with a date stamp and stored in history

-- The following are used in ifcfg scripts:
-- switch_ip
-- gateway
-- netmask
-- dhcp_config

require "ui_utils"
require "platform"
require "parselib"

Config = Config or {}

Config.validator_to_help = {
   [parse_ip]       = "a dotted IP address",
   [parse_int]      = "an integer",
   [parse_mac]      = "a colon separated MAC address",
   [parse_yes_no]   = "yes or no",
   [parse_hex]      = "a hex integer",
   [parse_range]    = "a range low-high",
   [parse_dpid]     = "a datapath id up to 16 hex-digits",
   [parse_vid]      = "a VLAN id, -1 to 4095",
   [parse_string_list] = "to be one of ",
}

-- Config vars and validators
Config.known_config_vars = {
   controller_ip = {
      validator = parse_ip,
      help = "the IP address of the controller",
   },
   controller_port = {
      validator = parse_int,
      help = "the TCP port for the controller connection",
   },
   ofp_options = {
      help = "the options passed to ofprotocol",
   },
   mgmt_if = {
      validator = parse_string_list,
      validator_arg = Platform.mgmt_if_allowed,
      help = "switch management interface name",
   },
   ip_addr = {
      validator = parse_ip,
      help = "switch management interface ip address",
   },
   netmask = {
      help = "switch management interface netmask",
   },
   gateway = {
      validator = parse_ip,
      help = "switch management interface gateway",
   },
   tap0_mac = {
      validator = parse_mac,
      help = "the switch dataplane interface",
   },
   dp_mgmt = {
      validator = parse_yes_no,
      help = "to enable or disable dataplane mgmt",
   },
   dp_mgmt_oob = {
      validator = parse_yes_no,
      help = "set out-of-band dataplane mgmt mode",
   },
   dp_mgmt_port = {
      validator = parse_int,
      help = "the OpenFlow port number of the fixed port for dp mgmt",
   },
   dp_mgmt_port_fixed = {
      validator = parse_yes_no,
      help = "enable fixed management port for dp_mgmt"
   },
   dp_mgmt_vid = {
      validator = parse_vid,
      help = "the VLAN id for dp mgmt or -1 for untagged"
   },
   dp_mgmt_vid_fixed = {
      validator = parse_yes_no,
      help = "enable fixed management VLAN for dp_mgmt"
   },
   system_ref = {
      help = "of switch for some display points",
   },
   hostname = {
      help = "the hostname of the switch"
   },
   disable_sysconf = {
      validator = parse_yes_no,
      help = "disable the system config script on startup",
   },
   disable_telnetd = {
      validator = parse_yes_no,
      help = "disable telnetd if set to yes"
   },
   disable_sshd = {
      validator = parse_yes_no,
      help = "disable sshd if set to yes"
   },
   disable_httpd = {
      validator = parse_yes_no,
      help = "disable httpd if set to yes"
   },
   datapath_id = {
      validator = parse_dpid,
      help = "the datapath ID for the OpenFlow instance",
   },
   fail_mode = {
      validator = parse_string_list,
      validator_arg = {"open", "closed", "host", "static"},
      help = "the fail behavior for the OpenFlow protocol",
   },
   log_level = {
      validator = parse_string_list,
      validator_arg = {"debug", "info", "warn", "error", "none"},
      help = "the logging level for the system",
   },
   use_factory_mac = {
      validator = parse_yes_no,
      help = "use the factory MAC address if yes"
   },
}

-- Simple parsing of lines 'export key = value'
function parse_config_line(line, config, regexp)
   local start, len = string.find(line, regexp)
   if not start or not len then
      ui_dbg_verb("config: Warning: could not parse line "..line.."\n")
      return
   end

   local value = string.sub(line, len + 1)

   local l = line:gsub('=', ' = ', 1) -- Make sure space around =
   local t = split(l, "%s+")
   if t[1] ~= "export" then
      ui_dbg_verb("config: Warning: No export for config line "..line.."\n")
      table.insert(t, 1, "export")
   end
   if t[3] ~= "=" then
      ui_dbg_verb("config: Error: No = where expected in "..line.."\n")
      return
   end
   local key = t[2]
   -- convert switch_ip to ip_addr
   if key == "switch_ip" then key = "ip_addr" end
   config[key] = trim_string(value)
   if not Config.known_config_vars[string.lower(key)] then
      ui_dbg_info("config: Info: Unknown key "..key.."\n")
   end
   ui_dbg_verb("config: Parsed config line: "..key.." = "..config[key].."\n")
end

-- Read in the current configuration
-- Add entries to the config table parameter
-- Return number of lines read or -1 on error with error string
function config_read(config, filename)
   filename = filename or Platform.cfg_filename

   local cfg_line_count = 0

   -- read config
   cfg_line_count, err_string = file_read(config, filename, '%s*export%s+[%a%d_]+%s*=')
   if (cfg_line_count == -1) then
      return -1, err_string
   end

   local mgmt_if_line_count = 0
   local mgmt_if
   if (config_var_is_set(config.mgmt_if)) then
      mgmt_if = config.mgmt_if
   else
      -- if management interface is not set, set it to the default value
      mgmt_if = Platform.mgmt_if or "eth0"
      config.mgmt_if = mgmt_if      
   end

   -- read mgmt ip config
   mgmt_if_line_count, errstring = ifcfg_read(mgmt_if, config)
   if (mgmt_if_line_count == -1) then
      ui_dbg_info(errstring)
      mgmt_if_line_count = 0
   end

   return cfg_line_count + mgmt_if_line_count
end

function sfs_save()
   -- Check if SFS should be used and save to it if so
   if Platform.cfg_use_sfs and Platform.cfg_use_sfs == 1 then
      if verbose then
         rv = os.execute("(cd "..Platform.sfs_parent_dir.." && sfs_create)")
      else
         rv = os.execute("(cd "..Platform.sfs_parent_dir.." && sfs_create > /dev/null)")
      end
      if rv ~= 0 then
         err_string = string.format("config_save: Error creating SFS "..
                                    "flash file from " .. 
                                    Platform.sfs_parent_dir .. "\n")
         return -1, err_string
      end
   end
   return 0
end

                                                                               
-- Generate a datapath ID from string containing an IPv4 address
-- Assuming the switch IP address is unique, this should give a unique dpid
-- Returns a string with each octet right justified with zero padding
-- Or nil if the conversion is not possible
-- E.g. 192.168.2.119 -> 192168002119
function ipv42dpid(str)
   local octets, accum
   octets = { string.find(str, "(%d+)%.(%d+)%.(%d+)%.(%d+)") }
   if octets then
      accum = ""
      for i = 3,6 do
         if octets[i] then
            accum = accum .. string.format("%03d", octets[i])
         end
      end
      return accum
   else
      return nil
   end
end


-- the config var can be:
--   not set at all
--   set, but with value "" or "not_set"
function config_var_is_set(v)
  local vset = false
  if v then
    local vtrim = trim_string(tostring(v))
    vset = (vtrim ~= "") and (vtrim ~= "not_set")
    ui_dbg_verb("config var trimmed to %s, result %s\n", vtrim, tostring(vset))
  else
    ui_dbg_verb("config var is nil\n")
  end
  return vset
end


-- certain config vars should not be printed into sysenv
function config_var_is_dump2sysenv(v)
  return not (v == "switch_ip" or v=="ip_addr" or v == "netmask" or v == "gateway")
end


-- Save current configuration
-- No sanitizing is done in this routine
function config_save(config, verbose)
   os.execute("mkdir -p "..Platform.cfg_history_dir)
   local cfg_history = Platform.cfg_history_dir .. os.date("%d%b%y-%H-%M")
   local file, msg =io.open(cfg_history, "r")
   local cfg_fname = Platform.cfg_filename
   local top_stuff = [[
#!/bin/sh
# This file contains environment variables.  It is sourced on initialization
# and is read and modified by user interface code.  Please only add export
# commands to this file.  Do not place other executable code in this file.

]]
   local mgmt_if
   if (config_var_is_set(config.mgmt_if)) then
      mgmt_if = config.mgmt_if
   else
      mgmt_if = Platform.mgmt_if or "eth0"
   end

   if file then
      ui_dbg_verb("config_save: Warning: Cfg history file %s replaced\n",
                  cfg_history)
      io.close(file)
   end

   rv = os.execute("cp " .. cfg_fname .. " " .. cfg_history)
   if rv ~= 0 then
      ui_dbg_verb("config: Warning: Could not copy %s to %s \n", cfg_fname,
                  cfg_history)
   end

   file, msg = io.open(cfg_fname, "w")
   if not file then
      err_string = string.format("Error:  Could not create %s\n", cfg_fname)
      return -1, err_string
   end

   -- Create datapath_id if necessary
   if not config_var_is_set(config.datapath_id) then
      if config_var_is_set(config.ip_addr) then
         config.datapath_id = ipv42dpid(config.ip_addr)
      end
   end

   -- Sort the variables
   local keys = get_keys_as_sorted_list(config)
   
   file:write(top_stuff)
   for i, k in ipairs(keys) do
      v = config[k]
      if config_var_is_set(v) and config_var_is_dump2sysenv(k) then
         ui_dbg_verb("config: export %s=%s\n", k, tostring(v))
         file:write("export "..k.."="..tostring(v).."\n")
      else
         ui_dbg_verb("config: not writing %s=%s\n", k, tostring(v))
      end
   end

   if config.__ADDITIONAL_CONTENTS__ then
      file:write(config.__ADDITIONAL_CONTENTS__)
   end
   io.close(file)

   -- save ifcfg-related variables
   ifcfg_create(mgmt_if, config)

   return sfs_save(verbose)
end

-- Clear the configuration; move sysenv, config.bcm. rc.soc, system_* 
-- to a saved location
-- This still needs work.  It should probably keep the controller address
-- and port number and clear everything else.
function config_clear()
   os.execute("mkdir -p "..Platform.cfg_history_dir)
   local cfg_history = Platform.cfg_history_dir .. os.date("%d%b%y-%H-%M")
   local file, msg = io.open(cfg_history, "r")

   if file then
      ui_dbg_verb("config_save: Warning: Cfg history file %s replaced\n",
                  cfg_history)
      io.close(file)
      os.execute("rm -f " .. cfg_history)
   end

   os.execute("mkdir -p "..cfg_history)
   
   -- Move existing files
   rv = os.execute("mv " .. Platform.cfg_filename .. " " .. cfg_history)

   sfs_dir = Platform.sfs_parent_dir .. "/sfs/"
   other_files = {"config.bcm ", "rc.soc ", "system_init ", "system_config "}
   for i, name in pairs(other_files) do
      fname = sfs_dir .. name
      os.execute("[ -e " .. fname .. " ] && mv " .. fname .. " " .. cfg_history)
   end

   return sfs_save()

end


-- Generate /etc/ifcfg-<interface> and save to overlay
function ifcfg_create(interface, values)
   local rv
   local dhcp_val

   if not interface then return end

   exec_str = "/sbin/ifcfg-gen"
   if (config_var_is_set(values.ip_addr)) then
      exec_str = exec_str .. " -i " .. values.ip_addr
   end
   if (config_var_is_set(values.netmask)) then
      exec_str = exec_str .. " -n " .. values.netmask
   end
   if (config_var_is_set(values.gateway)) then
      exec_str = exec_str .. " -g " .. values.gateway
   end

   exec_str = exec_str .. " " .. interface
   if (config_var_is_set(values.dhcp_config)) then
      dhcp_val = trim_string(values.dhcp_config)
   else
      dhcp_val = "disable"
   end
   exec_str = exec_str .. " " .. dhcp_val

   ui_dbg_verb("ifcfg_create: %s\n", exec_str)

   rv = os.execute(exec_str .. " > /dev/null")
   if rv ~= 0 then
      printf("error %d generating config for %s\n", rv, interface)
   end
end

-- read from /etc/ifcfg-<interface> and populate into config
-- returns lines read
function ifcfg_read(interface, config)
   if not interface then
      return -1, "Null interface"
   end

   return file_read(config, "/etc/ifcfg-" .. interface, '%s*[%a%d_]+%s*=')
end


-- generic file read function
-- returns number of lines read or -1 on error with error string
function file_read(config, filename, regexp)
   local cfg_file = io.open(filename)
   local count = 0

   if not cfg_file then
      local err_str = string.format("Configuration file %s " ..
                                    "not found\n", filename)
      return -1, err_str
   end
   for line in cfg_file:lines() do
      count = count + 1
      if line ~= "" and not string.find(line, '%s*#') then
         parse_config_line(line, config, regexp)
      end
   end

   return count
end

