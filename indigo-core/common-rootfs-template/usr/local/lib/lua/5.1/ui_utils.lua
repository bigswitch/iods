-- Copyright (c) 2011 Big Switch Networks
-- ui_utils.lua
-- Lua library with general utilities for the CLI and Web UI

require "platform"
require "global"
require "nw_defines"

-- Command server operation types
CS_MESSAGE_UNKNOWN = -1
CS_MESSAGE_ECHO = 0
CS_MESSAGE_PORT_CONFIG_SET = 1
CS_MESSAGE_PORT_CONFIG_GET = 2
CS_MESSAGE_PORT_STATISTICS_GET = 3
CS_MESSAGE_FLOW_TABLE_ENTRY_GET = 4
CS_MESSAGE_FLOW_TABLE_GET = 5
CS_MESSAGE_MANAGEMENT_STATISTICS_GET = 6
CS_MESSAGE_CONTROLLER_STATUS_GET = 7
CS_MESSAGE_LOGGING_LEVEL_SET = 8
CS_MESSAGE_LOGGING_LEVEL_GET = 9
CS_MESSAGE_FAIL_MECHANISM_OPEN_SET = 10
CS_MESSAGE_FAIL_MECHANISM_CLOSED_SET = 11
CS_MESSAGE_FAIL_MECHANISM_GET = 12

CS_REST_MORE_DATA = -1 -- Need more data (internally)
CS_REST_OKAY = 200
CS_REST_NOT_FOUND = 404
CS_REST_NOT_ALLOWED = 405
CS_REST_SERVER_ERROR = 500
CS_REST_NOT_IMPLEMENTED = 502
CS_REST_NOT_IMPLEMENTED = 502

REST_HEADER_MAX = 128

-- General protocol mappings

-- TODO:  Need to think about debug level vs logging etc.
-- Problem is that UI settings are not necessarily (or at least easily)
-- persistent across multiple operations
DBG_LVL_NONE = -1
DBG_LVL_ERROR = 0
DBG_LVL_WARN = 1
DBG_LVL_INFO = 2
DBG_LVL_VERB = 3
DBG_LVL_VVERB = 4

dbg_lvl_strings = {
   [DBG_LVL_NONE] = "none",
   [DBG_LVL_ERROR] = "error",
   [DBG_LVL_WARN] = "warn",
   [DBG_LVL_INFO] = "info",
   [DBG_LVL_VERB] = "verbose",
   [DBG_LVL_VVERB] = "vverb"
}
-- Emulate printf
function printf(...)
   local function wrapper(...)
      local str = string.format(...)
      -- TBD: MAKE THIS DEPENDENT ON STATE
      str = string.gsub(str, "\n", "\r\n")
      io.write(str)
   end
   local status, result = pcall(wrapper, ...)
   if not status then error(result, 2) end
end -- function

-- Null function to ignore a print
function no_printf(...) end

-- This runs first and disables all output
ui_dbg_error = no_printf
ui_dbg_warn = no_printf
ui_dbg_info = no_printf
ui_dbg_verb = no_printf
ui_dbg_vverb = no_printf

-- This determines the startup verbosity level
-- Comment out the versions you don't want activated
ui_dbg_error = printf
--ui_dbg_warn = printf
--ui_dbg_info = printf
--ui_dbg_verb = printf
--ui_dbg_vverb = printf

-- At run time, to turn on or off a debug level, set vars above to no_printf
function dbg_lvl_set(level)   
   if level >= DBG_LVL_VVERB then
      ui_dbg_vverb = printf
   else
      ui_dbg_vverb = no_printf
   end
   if level >= DBG_LVL_VERB then
      ui_dbg_verb = printf
   else
      ui_dbg_verb = no_printf
   end
   if level >= DBG_LVL_INFO then
      ui_dbg_info = printf
   else
      ui_dbg_info = no_printf
   end
   if level >= DBG_LVL_WARN then
      ui_dbg_warn = printf
   else
      ui_dbg_warn = no_printf
   end
   if level >= DBG_LVL_ERROR then
      ui_dbg_error = printf
   else
      ui_dbg_error = no_printf
   end

   Global.debug_level = level
end

-- Return true if value occurs in list
function value_in_list(val, list)
   for i,v in ipairs(list) do
      if val == v then return true end
   end
   return false
end

-- Split a string according to the re and return a table
function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
         table.insert(t, cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

-- Return boolean: is str[pos] an alpha character
function iptostring(ip)
   z = string.format("%08x", ip)
   n4 = tonumber(string.sub(z, -2), 16)
   n3 = tonumber(string.sub(z, -4, -3), 16)
   n2 = tonumber(string.sub(z, -6, -5), 16)
   n1 = tonumber(string.sub(z, -8, -7), 16)
   return string.format("%d.%d.%d.%d", n1, n2, n3, n4)
end

-- Return boolean: is str[pos] an alpha character
function is_alpha(str, pos)
   char = string.sub(str, pos, pos)
   return string.find(char, "%S")
end

-- Generic table dump
-- Set no_recursion to true to avoid calling recursively on tables
function generic_show(entry, prefix, no_recursion)
   if prefix == nil then prefix = "  " end
   -- For now, just print out key/value pairs; recurs on tables
   if not entry then
      printf("Empty\n")
      return
   end
   -- Fixme: Check for entry as number, string, etc
   if type(entry) ~= type({}) then
      printf("%s%-20s:  %s\n", prefix, "(scalar)", tostring(entry))
      return
   end
   local keys = {}
   for k, v in pairs(entry) do
      table.insert(keys, k)
   end
   table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)

   local pdone = false
   for i, k in ipairs(keys) do
      v = entry[k]
      if type(v) == type({}) then
         printf("%s%-20s: (table)\n", prefix, tostring(k))
         if not no_recursion then
            generic_show(v, prefix.."  ")
         end
      else
         printf("%s%-20s:  %s\n", prefix,tostring(k), tostring(v))
      end
      pdone = true
   end
   if not pdone then
      printf("Empty\n")
   end
end


-- Show the headers for a flow table
-- verbosity is one of full, extended or brief
function flow_entry_header(verbosity)
   if verbosity == 'full' then
      printf("Full dump of flow entries\n")
   elseif verbosity == 'extended' then
         printf("%-4s %-18s %-18s %-5s %-16s %-16s %-5s %-5s "..
                "%-4s %-4s %-9s %-6s %-6s\n", "Port", "L2 Source", "L2 Dest", 
                "VLAN", "IP Source", "IP Dest", "TCP", "TCP", "Idle", 
                "Hard", "Packets", "Out_P", "Cookie")
         printf("%-4s %-18s %-18s %-5s %-16s %-16s %-5s %-5s "..
                "%-4s %-4s %-9s %-6s %-6s\n", "", "", "", "", "", "",
                "Src", "Dest", "TO", "TO", "", "", "")
   else
      printf("%4s %16s %16s %6s %6s %6s %8s\n",
             "port", "L3src", "L3dst", "L4src", "L4dst", "Out_P", "packets")
   end
end

-- Show the headers for a flow table
-- verbosity is one of full, extended or brief
function flow_entry_display (verbosity, i, entry)
   local str
   local out_port="n/a"

   -- Find an output action if present
   if entry.actions then
      for i,v in ipairs(entry.actions) do
         if v.action_name == 'output' then
            out_port=tostring(v.port)
         end
      end
   end

   if verbosity == 'full' then
      printf("\nEntry %d\n", i)
      entry.nw_src = iptostring(entry.nw_src)
      entry.nw_src_mask = iptostring(entry.nw_src_mask)
      entry.nw_dst = iptostring(entry.nw_dst)
      entry.nw_dst_mask = iptostring(entry.nw_dst_mask)
      str = Network.dl_type_map[entry.dl_type] or "unknown"
      entry.dl_type = string.format("0x%x: %s", entry.dl_type, str)
      str = Network.nw_proto_map[entry.nw_proto] or "unknown"
      entry.nw_proto = string.format("%d: %s", entry.nw_proto, str)
      generic_show(entry)
   elseif verbosity == 'extended' then
      printf("%-4s %-18s %-18s %-5s %-16s %-16s %-5s %-5s "..
             "%-4s %-4s %-9s %-6s %-6s\n",
             tostring(entry.in_port),
             entry.dl_src,
             entry.dl_dst,
             tostring(entry.dl_vlan),
             iptostring(entry.nw_src),
             iptostring(entry.nw_dst),
             tostring(entry.tp_src),
             tostring(entry.tp_dst),
             tostring(entry.idle_timeout),
             tostring(entry.hard_timeout),
             tostring(entry.packet_count),
             out_port,
             tostring(entry.cookie))
   else
      printf("%4s %16s %16s %6s %6s %6s %8s\n", 
             tostring(entry.in_port),
             iptostring(entry.nw_src),
             iptostring(entry.nw_dst),
             tostring(entry.tp_src),
             tostring(entry.tp_dst),
             out_port,
             tostring(entry.packet_count))
   end
end

-- Return contents of file or nil if unable to read
function read_file(filename)
   local content = nil
   local file = io.open(filename, "r")
   if not file then
      content = nil
   else
      content = file:read("*all")
      file:close()
   end
   return content
end

function get_build_version(filename)
   filename = filename or "/etc/indigo-version"
   ver = read_file(filename)
   if not ver then ver = "unknown" end
   return ver
end

function get_month(m)
   if m == "Jan" then return 1 end
   if m == "Feb" then return 2 end
   if m == "Mar" then return 3 end
   if m == "Apr" then return 4 end
   if m == "May" then return 5 end
   if m == "Jun" then return 6 end
   if m == "Jul" then return 7 end
   if m == "Aug" then return 8 end
   if m == "Sep" then return 9 end
   if m == "Oct" then return 10 end
   if m == "Nov" then return 11 end
   if m == "Dec" then return 12 end
   ui_dgb_error("Could not parse month " .. tostring(m))
   return 1
end

function ctrl_log_parse_time(line)
   local year = os.date("%Y")
   local ar = split(line, "%W")
   local month = get_month(ar[1])
   local day = tonumber(ar[2])
   local hour = tonumber(ar[3])
   local min = tonumber(ar[4])
   local sec = tonumber(ar[5])

   return year, month, day, hour, min, sec
end

function ctrl_log_parse_ip(line)
   local str = string.gsub(line, ".*tcp:", "")
   str = string.gsub(str, ": conn.*", "")
   return str
end

function get_ctrl_history()
   -- Parse controller log for connections/disconnections
   -- Generate an array of entries (ip, cxn/dis, time), most recent first
   -- Also report current time
   local ctrl_hist = read_file(Platform.log_dir .. "/ofprotocol/current")
   local state = "unknown"
   local time = ""
   local ip = ""
   local entries = {}
   count = 1
   for i,line in ipairs(split(ctrl_hist, "\n")) do
      
      -- Ignore connections to local host for now
      if not string.find(line, "127.0.0.1") then
         if string.find(line, ": connected") then
            state = "connected"
            time = string.gsub(line, "|.*", "")
            ip = ctrl_log_parse_ip(line) or ""
            entries[count] = {state = "connected", 
                              time = time,
                              ctrl_ip = ip}
            count = count + 1
         elseif (string.find(line, "connecting") and
              state ~= "disconnected") then
            state = "disconnected"
            time = string.gsub(line, "|.*", "")
            entries[count] = {state = "disconnected",
                              time = time,
                              ctrl_ip = ""}
            count = count + 1
         end
      end
   end

   return entries
end

function get_switch_mac(iface)
   -- Get current switch mac from iface (or tap0 by default)
   iface = iface or "tap0"
   cmd = "ifconfig " .. iface .. " | grep HWaddr | sed -e 's/.*HWaddr //g'"
   local f = io.popen(cmd)
   local mac = f:read("*a")
   f:close()
   return mac
end

function get_switch_ip(iface)
   -- Get current switch IP from iface (or tap0 by default)
   iface = iface or "tap0"
   cmd = "ifconfig " .. iface .. " | grep addr: | sed -e 's/:/ /g' | awk '{ print $3 }'"
   local f = io.popen(cmd)
   local ipaddr = f:read("*a")
   f:close()
   return ipaddr
end

function get_switch_netmask(iface)
   -- Get current switch netmask from iface (or tap0 by default)
   iface = iface or "tap0"
   cmd = "ifconfig " .. iface .. " | grep addr: | sed -e 's/:/ /g' | awk '{ print $7 }'"
   local f = io.popen(cmd)
   local ipaddr = f:read("*a")
   f:close()
   return ipaddr
end

function get_switch_default_route()
   -- Get current switch default route
   iface = iface or "tap0"
   cmd = "route | grep default | awk '{ print $2 }'"
   local f = io.popen(cmd)
   local ipaddr = f:read("*a")
   f:close()
   return ipaddr
end

function merge_tables(t1, t2)
   if type(t1) == "table" and type(t2) == "table" then
      for k,v in pairs(t1) do t2[k] = v end
   end

   return t2
end

-- Given a table, extract the string keys to a new set (keys of a table)
function get_keys_as_set(tab)
   keys={}

   if tab then
      for k,v in pairs(tab) do
         if type(k) == "string" then
            keys[k] = true
         end
      end
   end
   return keys
end

-- Given a table, extract the string keys to a new set (keys of a table)
function get_values_as_set(tab)
   keys={}

   if tab then
      for k,v in pairs(tab) do
         if type(v) == "string" then
            keys[v] = true
         end
      end
   end
   return keys
end

-- Given a table, extract the string keys to a new set (keys of a table)
function get_keys_as_sorted_list(tab, fn)
   fn = fn or function(a,b) return tostring(a) < tostring(b) end
   local k, v, list

   list = {}
   if tab then
      for k, v in pairs(tab) do table.insert(list, k) end
      table.sort(list, fn)
   end

   return list
end

-- Return boolean indicating if tables t1 and t2 have same contents
function table_compare(t1, t2)
   if not t1 and not t2 then return true end
   if not t1 or not t2 then return false end

   if #t1 ~= #t2 then return false end
   for k,v in pairs(t1) do
      if not t2[k] or t2[k] ~= v then 
         print("Failed to find " .. k .. " in second tab")
         return false
      end
   end
   for k,v in pairs(t2) do
      if not t1[k] or t1[k] ~= v then 
         print("Failed to find " .. k .. " in first tab")
         return false
      end
   end
   return true
end

-- Count the number of elts in a set
-- If keyword is true, then only count string keys, not positional keys
function set_card(set, keyword_only)
   local count = 0
   local k,v

   if not set then return 0 end
   for k,v in pairs(set) do
      if not keyword_only or type(k) == "string" then count = count + 1 end
   end
   return count
end

-- Return an element of a set (any element may be returned)
function first_set_elt(set)
   if not set then return nil end
   for k,v in pairs(set) do
      return k
   end
end

-- Boolean indication if whether val is a member of the set or list values
function is_member(val, values)
   for k,v in pairs(values) do
      if val == k then return true end
      if val == v then return true end
   end
   return false
end

-- Return boolean indicating if tables t1 and t2 represent same sets (keys)
function set_compare(t1, t2)
   if not t1 and not t2 then return true end
   if not t1 or not t2 then return false end

   if #t1 ~= #t2 then return false end
   for k,v in ipairs(t1) do
      found = false
      for k2,v2 in ipairs(t2) do
         if v == v2 then
            found = true
            break
         end
      end
      if not found then
         print("Failed on param " .. v)
         return false
      end
   end
   return true
end

-- Return the longest common initial substring of strings s1 and s2
function common_root(s1, s2)
   local offset

   for offset=#s1,1,-1 do
      if string.sub(s1, 1, offset) == string.sub(s2, 1, offset) then
         return string.sub(s1, 1, offset)
      end
   end

   return ""
end

-- Return the longest matching prefix of strings in list
function longest_prefix(list)
   local longest = ""

   if list[1] then
      longest = list[1]
      for idx=2,#list do
         longest = common_root(longest, list[idx])
      end
   end

   return longest
end

-- Return the longest matching prefix of strings in a set (keys of table)
function longest_prefix_set(set)
   local longest = nil

   for k, v in pairs(set) do
      if type(k) == "string" then
         if not longest then
            longest = k
         else
            longest = common_root(longest, k)
            if longest == "" then break end
         end
      end
   end

   return longest or ""
end

-- Return as a set (keys to table)  the list of keys in table
-- that have s as a prefix.  
function table_key_matches(tab, s)
   matches = {}
   prefix = ""

   if tab and s then
      for k,v in pairs(tab) do
         if type(k) == "string" then
            if string.find(k, s) == 1 then
               matches[k] = true
            end
         end
      end
   end

   return matches, longest_prefix_set(matches)
end

-- Return as a set the values in table that have s as a prefix.  
function table_value_matches(tab, s)
   matches = {}
   prefix = ""

   if tab and s then
      for k,v in pairs(tab) do
         if type(v) == "string" then
            if string.find(v, s) == 1 then
               matches[v] = true
            end
         end
      end
   end

   return matches, longest_prefix_set(matches)
end

-- Trim whitespace from start/end of string
function trim_string(str)
   if type(str) ~= "string" then return "" end

   -- from PiL2 20.4
   return (str:gsub("^%s*(.-)%s*$", "%1"))
end

-- str and last token on line should share a root.  
-- Replace that last token by str
-- FIXME:  Only works for last token right now
function extend_last_token(line, str)
   s,e = line:find("%S+$")

   -- If space at end, just add str
   if not s then return line .. str end

   -- Verify match on last token
   last_token = line:sub(s)
   if str:find(last_token) ~= 1 then
      print("Internal error in extend last token: " .. line .. " " .. str)
      return line
   end
   line = line:sub(1,s - 1)
   line = line .. str
   return line
end

-- Map a string argument to an integer debug level
function get_debug_arg(str)
   if type(str) ~= "string" then return DBG_LVL_ERROR end

   str = str:lower()
   for k,v in pairs(dbg_lvl_strings) do
      if v:find(str) == 1 then
         return k
      end
   end

   return DBG_LVL_ERROR
end
