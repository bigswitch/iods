-- (c) 2011 Big Switch Networks
-- The core interpreter and defines for the CLI

require "ui_utils"
require "ui_config"
require "parselib"
require "cli_edit"
require "cli_config"
require "cli_port"
require "cli_actions"

----------------------------------------------------------------
-- Help command
----------------------------------------------------------------

local help_str = "Show available commands\
help: List command names\
help <command>: Show help for command\
help all: Show all help for all commands"

function help_parser(command, orig_line, line, parsed)
   local completions = get_keys_as_set(Global.command_table)

   line = trim_string(line)
   if line and line ~= "" then
      local token = get_token(line)

      if str == "full" or str == "all" or Global.command_table[token] then
         return 0, nil, nil, ""
      end

      local completions = table_key_matches(completions, token)
      if set_card(completions) > 0 then
         return 1, nil, completions, ""
      end
      return -1, nil, nil, "No command " .. token
   end

   return 0, nil, completions, ""
end

function param_help(command_entry)
   pt = command_entry.parse_table
   local keys = get_keys_as_sorted_list(pt)

   if set_card(keys) > 0 then
      printf("Parameters for command '%s':\n", command_entry.command)
      for i,k in ipairs(keys) do
         local fmt -- For displaying posn vs keyword
         if type(k) == "number" then
            fmt = "    %-3d (Positional)   : %s\n"
         else
            fmt = "    %-15s    : %s\n"
         end
         printf(fmt, k, pt[k].help)
      end
   end
end

function cli_help(line, command_table)
   -- First see if there's a second argument
   local str,line = get_token(line)
   local k, v, keys

   if str then
      str,line = get_token(line)
      if str then str = str:lower() end
      if str == "help" then
         printf(help_str .. "\n")
         return
      end
   end

   if not str then
      -- Print names of commands
      printf("Commands available:\n")
      keys = get_keys_as_sorted_list(command_table)
      for _,k in ipairs(keys) do
         printf("%-15s :   %s\n", k, command_table[k].brief_help)
      end
   elseif str == "full" or str == "all" then
      -- Print all help for all commands
      keys = get_keys_as_sorted_list(command_table)
      for _,k in ipairs(keys) do
         v = command_table[k]
         printf("%s: %s\n", k, v.help)
         param_help(v)
         printf("\n")
      end
   elseif command_table[str] then
      printf("%s: %s\n", str, command_table[str].help)
      param_help(command_table[str])
      printf("\n")
   else
      printf("Unknown command:  %s\n", str)
   end
end

function history_handler()
   -- This is really a privacy violation accessing the CLI object
   printf("Commmand history, oldest first\n")
   for i,cmd in ipairs(CLI.history) do
      printf("%3d: %s\n", i, cmd)
   end

   return 0
end

function cli_stat_handler()
   printf("Debug CLI state dump\n")
   generic_show(CLI, "    ", true)
   printf("Command server settings\n")
   generic_show(CLI.cmdsrv, "    ", true)
   printf("Global variables\n")
   generic_show(Global, "    ", true)
   return 0
end

----------------------------------------------------------------
----------------------------------------------------------------
-- CLI Command table definition
----------------------------------------------------------------
----------------------------------------------------------------

local command_table = {
   port = {
      command = "port",
      parse_table = port_parse_tab,
      parser = port_parser,
      help = port_help,
      brief_help = "Show/set/stats for ports",
      handler = port_handler
   },
   ps = { -- Syn for port show
      command = "ps",
      parse_table = {
         {
            key="portspec", 
            parser=parse_port_spec,
            optional = true,
            help="Port list like * or 1,2,4-8"
         },
         ["-l"] = {
            key="-l", 
            help="Show only ports with link"
         }
      },
      help = port_help,
      brief_help = "Show port info",
      handler = port_handler
   },
   cli_stat = {
      command = "cli_stat",
      help = "Show debug info on CLI",
      brief_help = "Show debug info on CLI",
      handler = cli_stat_handler
   },
   history = {
      command = "history",
      help = "Show command history",
      brief_help = "Show command history",
      handler = history_handler
   },
   config = {
      command = "config",
      parse_table = config_parse_tab,
      parser = config_parser,
      help = config_help,
      brief_help = "Show/modify running or saved cfg",
      handler = config_handler
   },
   help = {
      command = "help",
      help = help_str,
      brief_help = "Show help for commands",
      parser = help_parser,
      -- Handled specially in CLI loop
      handler = function () return 0 end
   },
   quit = {
      command = "quit",
      help = "Quit the CLI (if supported)",
      brief_help = "Quit the CLI (if supported)",
      -- Handled specially in CLI loop
      handler = function () return 1 end
   },
   cxn_history = {
      command = "cxn_history",
      help = "Display controller connection history",
      brief_help = "Show ctrl connection history",
      handler = cxn_history_handler
   },
   drvcmd = {
      command = "drvcmd",
      help = "Run a switch ASIC driver command",
      brief_help = "Run a switch command",
      handler = drvcmd_handler
   },
   version = {
      command = "version",
      help = "Display the version of the firmware",
      brief_help = "Show firmware version",
      handler = version_handler
   },
   debug = {
      command = "debug",
      parse_table = {
         {
            key = "level",
            parser = parse_string_list,
            pargs = dbg_lvl_strings,
            help = "Debug level"
         },
      },
      help = "Set the system debug level",
      brief_help = "Set debug level",
      handler = debug_handler
   },
   flowtable = {
      command = "flowtable",
      parse_table = {
         {
            key = "verbosity",
            parser = parse_string_list,
            pargs = {"full", "extended", "brief"},
            help = "brief, extended or full: How much info to show"
         },
      },
      help = "flowtable [full | extended]: Show the flowtable ",
      brief_help = "Show the flowtable",
      handler = flowtable_handler
   },
   echo = {
      command = "echo",
      help = "Call the command server with an echo request of line",
      brief_help = "Echo request to cmd server",
      handler = echo_handler
   },
   status = {
      command = "status",
      help = "Display the status of the switch",
      brief_help = "Show switch status",
      handler = status_handler
   },
   mgmtstats = {
      command = "mgmtstats",
      help = "Display the management statistics",
      brief_help = "Show management statistics",
      handler = mgmtstats_handler
   },
   enable = {
      command = "enable",
      help = "Enter the enable mode",
      brief_help = "Enter the enable mode",
      handler = enable_handler
   },
   shell = {
      command = "shell",
      help = "Run the remainder of the line as a shell command",
      brief_help = "Run a shell command",
      handler = shell_handler
   },
   lua = {
      command = "lua",
      help = "Evaluate a lua expression",
      brief_help = "Evaluate a lua expression",
      handler = lua_handler
   },
   restart = {
      command = "restart",
      help = "Restart the OpenFlow daemons",
      brief_help = "Restart the OpenFlow daemons",
      handler = restart_handler
   },
}


-- Defines the command server connection
cmdsrv_state = {
   host = "127.0.0.1",
   --   host = "192.168.2.29",
   port = 8088
}

--
-- CLI:   The main state structure
--
-- cmdsrv: The structure representing the connection to the command server
-- prompt: Current prompt to use
-- client: For remote connections
-- line:   Current input line

CLI = { 
   cmdsrv           = cmdsrv_state,
   client           = nil,
   enabled          = true,
   interactive      = true,

   prompt           = "SwitchCLI",
   line             = "",
   position         = 0,

   history          = {},
   history_max      = 100,
   history_ptr      = nil,
}

function interpreter_init()
   -- Initialize prompt
   local config = {}
   config_read(config, Platform.cfg_filename .. ".running")
   if config and config.system_ref then
      CLI.prompt = config.system_ref .. "-CLI"
   end
   
   Global.command_table = command_table
end

-- rv = process_line(table, line, interactive)
--
-- Return 0 on success
-- Return 1 for exit
-- Return -1, err_str if internal error
function process_line(command_table, line, interactive)
   local token, rv, cmd_entry, parsed, completions, p_rv
   local str = ""

   ui_dbg_verb("Processing line %s\n", line)
   -- Special processing for quit, help etc
   token = get_token(line)
   if token then 
      if token:find("--", 1, true) == 1 then return 0 end
      if token:find("^#") then return 0 end
      token = token:lower()
      if token == "quit" or token == "exit" then return 1 end
      if token == "help" then
         cli_help(line, Global.command_table)
         return 0
      end
   else
      return 0
   end

   ui_dbg_verb("Parsing line %s\n", line)
   -- Process with command table
   p_rv, cmd_entry, parsed, completions, str = parse_line(line, command_table)
   rv = p_rv

   ui_dbg_verb("Parse result %s\n", p_rv)

   -- If successfully parsed, run the command
   if p_rv == 0 then
      ui_dbg_verb("Running command %s\n", cmd_entry.command)
      rv, str = cmd_entry.handler(cmd_entry.command, line, parsed)
      ui_dbg_verb("Handler result %d: %s\n", rv, str or "")
   end

   if not interactive then
      if rv == 0 then return 0 end
      if rv == 1 then return -1, "Incomplete input, non-interactive" end
      return -1, str
   end

   -- Interactive here after

   if rv == 1 then
      if completions then
         printf("Incomplete input.  Valid completions:\n")
         for k,v in pairs(completions) do
            printf(k .. "\n")
         end
      elseif str then
         printf("Incomplete input.  Need %s\n", str)
      else
         printf("Incomplete input.\n")
      end
   elseif rv == -1 then
      if p_rv == -1 then
         printf("Error parsing input. %s\n", str)
      else
         printf("Error handing command %s. %s\n", cmd_entry.command, str)
      end
   end

   return 0
end

