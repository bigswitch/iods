-- (c) 2010 Big Switch Networks
--
-- cli_config.lua
--

require "ui_utils"
require "parselib"

config_help=[[Show or set configuration parameters
config <sub-command> [<variable> [<value>] ]
Examples:
    config help              : Display known config variables
    config clean             : Remove unknown cfg vars and translate old ones
    config show              : Show all variables in saved config
    config show dp_mgmt      : Show the value of avar in saved config
    config running           : Show all variables in running config
    config set dp_mgmt yes   : Set dp_mgmt to yes in saved config
    config delete dp_mgmt    : Delete dp_mgmt from saved config
]]

config_subcmds = { "set", "show", "running", "delete", "help", "clean" }

config_parse_tab = {
   {
      key="subcommand", 
      parser=parse_string_list, 
      pargs=config_subcmds,
      help="Subcommand: show, set, running, delete, clean"
   },
   {
      key="variable",
      optional=true,
      help="Variable to show, set or delete"
   },
}

-- Return true if parameter value is valid, false, string otherwise
function validate_param(var, value)
   var_desc = Config.known_config_vars[var]
   if var_desc then
      dator = var_desc.validator
      dator_arg = var_desc.validator_arg
   else
      ui_dbg_verb("Config parse: No variable description for " .. var)
   end

   if dator then
      if not dator(value, dator_arg) then
         -- TODO:  Make this an error?  Move to parser? Add -f to force?
         local dator_help = Config.validator_to_help[dator]
         str = "Variable '" .. var .. "' with value \n    '" .. tostring(value)
         str = str .. "'\n    fails validator:  Needs " .. dator_help

         -- only parse_string_list has a dator_arg
         if dator_arg then
            str = str .. "\n   "
            for k,v in ipairs(dator_arg) do 
               str = str .. " " .. v
            end
         end

         return false, str
      end
   else
      ui_dbg_verb("Config parse: No validator for " .. var)
   end
   return true
end

-- Line is "rest" of line after command
-- Get variable for show and running; get var and value for set
function config_parser(command, orig_line, line, parsed)
   local token, rest_of_line
   local completions = {}
   local rv, str
   local have_var = false

   parsed=parsed or {}

   if not parsed.subcommand then
      return 1, nil, get_values_as_set(config_subcmds), "subcommand"
   end

   if parsed.variable then
      var,line = get_token(line, 2) -- Skip cmd and var; update line
      line = trim_string(line)

      if line == "" then
         if not Config.known_config_vars[parsed.variable] then
            completions = table_key_matches(Config.known_config_vars, 
                                            parsed.variable)
            if set_card(completions) == 0 then completions = nil end
         end
      end
   else
      completions = get_keys_as_set(Config.known_config_vars)
   end

   if parsed.subcommand == "set" then
      -- TODO: Give continuations of (known) config variables?
      if not parsed.variable then
         return 1, nil, completions, "Configuration variable to set"
      end

      if line == "" then
         str = "Complete variable or give value"
         if orig_line:find("%s+$") then str = "Value for variable" end
         return 1, nil, completions, str
      end
      parsed.value = trim_string(line)
      rv, str = validate_param(parsed.variable, parsed.value)
      if not rv then
         return -1, nil, nil, str
      end
   elseif parsed.subcommand == "delete" then
      if not parsed.variable then
         return 1, nil, completions, "Configuration variable to delete"
      end
   end

   return 0, parsed, completions, ""
end

-- Show one or more variables from a config table
function show_config(config, var, source)
   if var then
      if config[var] then
         printf("%s(%s): %s\n", var, source, tostring(config[var]))
      else
         printf("%s is not defined in %s configuration\n", var, source)
      end
   else
      printf("%s configuration variables:\n", source)
      generic_show(config)
   end
end

-- Handler for the config command
function config_handler(command, line, parsed)
   local config = {}
   local rv, str
   local dator = nil -- validator
   local dator_arg = nil

   local var = parsed.variable
   local cmd = parsed.subcommand

   if cmd == "running" then
      local filename = Platform.cfg_filename .. ".running"
      rv,str = config_read(config, filename)
      if rv < 0 then return rv, str end
      show_config(config, var, "running")
   elseif cmd == "clean" then
      rv,str = config_read(config, filename)
      if rv < 0 then return rv, str end
      if config.telnet_enable == "no" then
         config.disable_telnet = "yes"
      end
      if config.DEV_ADDR then
         config.system_ref = config.DEV_ADDR
      end
      if config.switch_ref then
         config.system_ref = config.switch_ref
      end
      if config.ctrlip then
         config.controller_ip = config.ctrlip
      end
      if config.ctrlport then
         config.controller_port = config.ctrlport
      end
      if config.switchip then
         config.switchip = config.switchip
      end
      for k,v in pairs(config) do
         if not Config.known_config_vars[k] then
            printf("Deleting %s (value %s)\n", k, v)
            config[k] = nil
         end
      end
      
      return config_save(config)
   elseif cmd == "show" then
      rv,str = config_read(config)
      if rv < 0 then return rv, str end
      show_config(config, var, "saved")
   elseif cmd == "set" then
      var_desc = Config.known_config_vars[var]
      if var_desc then
         dator = var_desc.validator
         dator_arg = var_desc.validator_arg
      end
      if dator and not dator(parsed.value, dator_arg) then
         -- TODO:  Make this an error?  Move to parser? Add -f to force?
         local dator_help = Config.validator_to_help[dator]
         ui_dbg_info("Warning: variable %s, value %s fails validator: %s\n",
                     var, tostring(parsed.value), dator_help)
      end
      rv,str = config_read(config)
      if rv < 0 then return rv, str end
      config[var] = parsed.value
      ui_dbg_info("Saving variable %s: %s\n", var,
                  tostring(parsed.value))
      return config_save(config)
   elseif cmd == "delete" then
      rv,str = config_read(config)
      if rv < 0 then return rv, str end
      config[var] = nil
      ui_dbg_info("Deleting variable %s\n", var)
      return config_save(config)
   elseif cmd == "help" then
      if var then
         var_desc = Config.known_config_vars[var]
         if var_desc then
            dator = var_desc.validator
            local str = Config.validator_to_help[dator] or "a string"
            printf("Config variable %s takes a %s\nrepresenting %s\n",
                   var, str, var_desc.help)
         else
            printf("The variable %s is not known; " .. 
                   "it can be set as a string\n", var)
         end
      else
         printf("Known config variables:\n")
         for k,v in pairs(Config.known_config_vars) do
            printf("  %-20s : %s\n", k, v.help)
         end
      end
   else
      return -1, "Unknown subcommand: " .. cmd
   end

   return 0
end
