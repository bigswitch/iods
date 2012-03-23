-- (c) 2010 Big Switch Networks
-- CLI action handlers for man CLI functions (the less involved ones)

require "json"
require "ui_rest"
require "ui_cs_cxn"
require "ui_cs_op"
require "ui_utils"
require "ui_config"

-- Connection history reporter
function cxn_history_handler()
   entries = get_ctrl_history()
   printf("Current time: %s\n", os.date())
   for i,ent in ipairs(entries) do
      printf("%s: %s: %s\n", os.date(ent.time), ent.state, ent.ctrl_ip)
   end

   return 0, ""
end

-- Run a drive command
function drvcmd_handler(command, line, parsed)
   _, cmd = string.find(line, "drvcmd")
   local str = string.sub(line, cmd + 2)
   print("Running command: " .. str)

   local status, results, errstr = cs_drvcmd(0, str)
   if status ~= nil then 
      report_rest_status(status, errstr)
   end
   if reply == nil then
      ui_dbg_info("No data returned\n")
   else
      printf("Got reply %s\n", reply)
   end   

   return 0, ""
end

-- Report version
function version_handler()
   printf("Firmware version: \n  " .. Global.version .. "\n")

   return 0, ""
end

-- Get/set debug level
function debug_handler(command, line, parsed)
   if set_card(parsed) == 0 then -- Show level
      printf("Current debug level is %s (%d)\n", 
             dbg_lvl_strings[Global.debug_level], Global.debug_level)
   else
      dbg_lvl_set(get_debug_arg(parsed.level))
      cs_loglevel_set(parsed.level)
   end
   return 0, ""
end

function flowtable_handler(command, line, parsed)
   printf("Flow table show\n")
   status, results, err_str = cs_flowtable_get()
   report_rest_status(status, err_str)

   if results == nil or #results == 0 then
      return -1, "No flow table entries returned"
   end
   flow_entry_header(parsed.verbosity)

   for i, entry in ipairs(results) do
      flow_entry_display(parsed.verbosity, i, entry)
   end

   return 0, ""
end

function echo_handler(command, line, parsed)
   _, eoecho = string.find(line, "echo")
   local str = string.sub(line, eoecho + 2)

   ui_dbg_verb("Requesting echo: \n".. str)
   local json_table = { ["string"] = tostring(str) }
   local json_str = Json.Encode(json_table)

   local hdr = setup_rest_header("GET", CS_URI_PREFIX .. "echo", #json_str)
   local buf = hdr.packed_header .. json_str

   local reply = {}
   local bytes = 0

   reply, bytes = transact(buf)
   if bytes < 0 then
      return -1, "Error on transaction: " .. err_str or ""
   end
   if reply == nil then
      return -1, "Error on echo transaction"
   else
      printf("Got reply %s\n", reply)
      -- todo decode json content and display
   end

   return 0, ""
end

function status_handler()
   ui_dbg_verb("Requesting switch status\n")
   status, results, err_str = cs_info_get()
   report_rest_status(status, err_str)

   if results == nil or #results == 0 then
      return -1, "No switch information returned: " .. err_str or ""
   end

   printf("Switch status report:\n")
   for i, entry in ipairs(results) do
      printf("%s\n", entry.info)
   end

   return 0, ""
end

function mgmtstats_handler()
   ui_dbg_verb("Requesting management statistics\n")
   status, results, err_str = cs_mgmt_stats_get()
   report_rest_status(status, err_str)

   if results == nil or #results == 0 then
      return -1, "No management statistics information returned"
   end

   printf("Management statistics report:\n")
   generic_show(results)

   return 0, ""
end

function enable_handler()
   printf("Always enabled for now\n")

   return 0, ""
end

function shell_handler(command, line, parsed)
   local cmd = string.gsub(line, "shell ", "", 1)
   printf("Running shell command: %s\n", cmd)
   os.execute(cmd)

   return 0, ""
end

function lua_handler(command, line, parsed)
   local cmd = string.gsub(line, "lua ", "", 1)
   local f = loadstring(cmd)
   if f then
      printf("Running lua command: %s\n", cmd)
      f()
   else
      printf("Empty command\n")
   end

   return 0, ""
end

function report_rest_status(status, err_str)
   if status ~= CS_REST_OKAY then
      if not status then
         printf("ERROR: Status nil, operation did not complete.\n")
      else
         if cs_rest_status_strings[tonumber(status)] then
            printf("Warning: Received error status %d: %s\n", 
                   tonumber(status), cs_rest_status_strings[tonumber(status)])
         else
            printf("Warning: Unknown error status %d\n", tonumber(status))
         end
      end
      if err_str then
         printf("Error string given: %s\n", err_str)
      end
   end
end


-- handle CLI invocation of of-restart
function restart_handler()
   local rv

   printf("restarting openflow daemons...\n")
   rv = os.execute("/sbin/of-restart > /dev/null")
   if rv ~= 0 then
      printf("error %d restarting\n", rv)
   end

   return 0, ""
end


