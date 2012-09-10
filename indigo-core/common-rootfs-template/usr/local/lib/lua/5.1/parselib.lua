-- Copyright (c) Big Switch Networks
-- parselib.lua
-- Library of parsing routines for CLI

require "ui_utils"
require "global"

----------------------------------------------------------------
-- Generic utilities related to parsing
----------------------------------------------------------------

-- Get next non-space token, return token and rest of line
-- Does not prune spaces from start of line
-- If count is specified, get skip to that token instance.
--     1 is same as not passing count
--     n gets the n-th token
function get_token(line, count)
   local s, e, token

   if not line then return nil, nil end

   count = count or 1
   for i=1,count do
      s, e = line:find("%S+")
      if not s then return nil, line end

      token = line:sub(s, e)
      line = line:sub(e + 1)
   end

   return token, line
end

----------------------------------------------------------------
-- Routines to validate a core parser, parse list or cmd table
----------------------------------------------------------------

-- Validate a parse instance; return nil if okay, error string otherwise
function validate_parse_instance(pi)
   if type(pi) ~= "table" then return "Not a table" end
   if type(pi.help) ~= "string" then return "No help string" end
   if type(pi.key) ~= "string" then return "No key" end
   if pi.parser then
      if type(pi.parser) ~= "function" then return "No parser function" end
   end
   local valid_keys = {"help", "key", "parser", "pargs", "optional"}
   for k,v in pairs(pi) do
      if not is_member(k, valid_keys) then return "Bad pi key " .. k end
   end

   return nil
end

-- Validate a parse table; return nil if okay, error string otherwise
function validate_parse_table(parse_tab)
    local i, pi, str

   if type(parse_tab) ~= "table" then 
      return "Parser not a table"
   end

   for k,pi in pairs(parse_tab) do
      str = validate_parse_instance(pi)
      if str then return "Instance " .. k .. ": " .. str end
      if type(k) == "string" then
         if k ~= pi.key then return "Key mismatch for " .. k end
      end
   end

   return nil
end

function validate_command_table(command_tab)
   if type(command_tab) ~= "table" then 
      return "Not a table"
   end

   for k,cmd in pairs(command_tab) do
      if type(k) ~= "string" then
         return "Non-string key in command table"
      end
      if not cmd.command then
         return "Missing command for " .. k
      end
      if k ~= cmd.command then
         return "Command " .. k .. " mismatch " .. cmd.command
      end
      if not cmd.help then
         return "No help string for " .. k
      end
      if not cmd.brief_help then
         return "No brief help string for " .. k
      end
      if cmd.parse_table then
         str = validate_parse_table(cmd.parse_table)
         if str then
            return "Bad parse table object for " .. k .. ": " .. str
         end
      end
      if cmd.parser and type(cmd.parser) ~= "function" then 
         return "Bad parser function for " .. k
      end
      if type(cmd.handler) ~= "function" then
         return "Bad handler function for " .. k
      end
      local valid_keys = {"help", "command", "parser", "handler", 
                          "parse_table", "brief_help"}
      for ck,v in pairs(cmd) do
         if not is_member(ck, valid_keys) then 
            return "Bad cmd key " .. ck .. " for cmd " .. k
         end
      end
   end   

   return nil   
end


----------------------------------------------------------------
-- Parse a set of parameters according to a parse list
----------------------------------------------------------------

-- Remove keys from tab that do not have str as an initial prefix
function remove_mismatches(tab, str)
   local remove = {}
   for k,v in pairs(tab) do
      if k:find(str) ~= 1 then tab[k] = nil end
   end
end

-- Make dest table look like source w/o changing reference
function table_copy(dest, source)
   dest = dest or {} -- Should probably flag as an error
   for k,v in pairs(dest) do dest[k] = nil end
   for k,v in pairs(source) do dest[k] = v end
end

-- Parse positional parameters from a line
-- The tables parsed_vals and completions are updated by this routine
-- rc, line, str = parse_positional(line, parse_tab, parsed_vals, completions)
function parse_positional(line, parse_tab, parsed_vals, completions)
   local i, pi
   local rc = 0
   local comps = {}
   local ret_str = ""

   -- Parse positional parameters
   for i,pi in ipairs(parse_tab) do
      -- If next token has = then break from positional params
      if line:find("%s*%S+%s*=") == 1 then break end

      -- If next token starts with '-' break from positional params
      if line:find("%s*-") == 1 then break end

      ui_dbg_vverb("parse_posn: position %d, key %s. %s\n", i, pi.key, line)
      if pi.parser then
         pval, line, comps = pi.parser(line, pi.pargs)
      else
         pval, line = get_token(line)
      end
      if pval == nil then
         if comps then
            table_copy(completions, comps)
            return 1, line, pi.help
         end
         if pi.optional then
            return 0, line, ""
         end
         return -1, line, "Parse error at param " .. i .. ": " .. pi.help
      end
      ui_dbg_vverb("parse_posn: value %s\n", tostring(pval))
      parsed_vals[pi.key] = pval
      line = trim_string(line)
      if not line or line == "" then break end
   end
   return rc, line, ret_str
end

-- Parse keyword parameters from a line
-- The table parsed_vals is updated by this routine
-- rc, line, str = 
--     parse_keywords(line, parse_tab, parsed_vals, completions)
function parse_keywords(line, parse_tab, parsed_vals, completions)
   local i, pi, rc = 0
   local ret_str = nil
   local key, str_val

   ui_dbg_vverb("parse_keyword : line %s\n", line)

   -- TODO: Protect quoted strings
   line = trim_string(line)
   line = string.gsub(line, "=", " = ") -- Parse = as token
   while line ~= "" do
      key, line = get_token(line)
      line = trim_string(line)
      if not key then break end
      ui_dbg_vverb("parse_keyword: key %s\n", key)
      pi = parse_tab[key]
      if not pi then -- Didn't find key in parse table
         if line == "" then -- end of line, look for completions
            remove_mismatches(completions, key)
            if set_card(completions) == 0 then
               return -1, line, "Token error at: " .. key
            end
            return 1, line, ""
         else
            return -1, line, "Token error at: " .. key
         end
      end

      -- If next token is =, get following token as value
      -- If next token is not =, use empty string as value
      str_val = ""
      eq, line_tmp  = get_token(line)
      if eq == "=" then -- Parse with empty string for str_val
         line = line_tmp
         if line == "" then
            -- Need value for key
            if pi.parser == parse_yes_no then
               table_copy(completions, {yes=true, no=true})
            end
            return 1, line, "Parameter value for key " .. key
         end
         str_val, line = get_token(line)
      end

      ui_dbg_vverb("parse_keyword: str_val %s\n", str_val)

      if pi.parser then 
         pval = pi.parser(str_val, pi.pargs)
      else -- If no parser and empty string, it's a flag; mark as true
         pval = str_val
         if str_val == "" then pval = true end
      end
      if pval == nil then
         ui_dbg_vverb("parse_keyword: nil parsed value for key %s\n", key)
         str = "Error parsing value for " .. key .. ": " .. pi.help
         return -1, line, str
      end
      parsed_vals[pi.key] = pval
      completions[key] = nil
   end
      
   return 0, line, ""
end

-- parse_params:  Parse a line of text according to the passed param descs
--   rc, ptab, completions, str = parse_params(line, parse_tab)
--
-- Parameters
--   line:  The input to parse
--   parse_tab:  A table including positional and keyword parse instances
--
-- Return Values
--   rc:  Return code.  0 success, 1 incomplete, -1 error
--   parsed_vals:  On success, table of parsed values
--   completions:  The set of possible completions if no error
--   str:  rc == 1: Description of next param;  rc == -1: what's wrong
--
-- Positional parameters are parsed first; then keyword params
-- Positional param parsing ends:
--     If = is seen in the next input token
--
--     If a nil parse_key is given in the next positional parse table entry
--     
-- Keyword params are always optional
-- TODO:  Recognize quoted strings and parse appropriately
-- NOTE:  = cannot be used in a parameter value
-- 
function parse_params(line, parse_tab)
   local parsed_vals = {}
   local pval, parser, str, tmp_line
   local i, pi, rc
   local completions = {}

   ui_dbg_vverb("parse_params: %s\n", line)

   rc, line, str = parse_positional(line, parse_tab, parsed_vals, completions)

   if rc ~= 0 then
      ui_dbg_vverb("parse_params: Return after posn args with rc %d\n", rc)
      return rc, parsed_vals, completions, str
   end

   completions = get_keys_as_set(parse_tab)
   if not line or line == "" then  -- No more tokens is acceptable
      ui_dbg_vverb("parse_params: No keywords in line\n")
      return 0, parsed_vals, completions, str
   end

   -- If no keywords in parse_tab, then done
   if set_card(parse_tab, true) > 0 then
      rc, line, str = parse_keywords(line, parse_tab, parsed_vals, completions)
   end

   ui_dbg_vverb("parse_params: Returning with rc %d\n", rc)
   return rc, parsed_vals, completions, str
end


----------------------------------------------------------------
-- Parse a line of input according to a command table
----------------------------------------------------------------

-- parse_line:  Run the parse algorithm on a line of input
-- 
--   rc, cmd, parsed, completions, str = parse_line(line, command_table)
--
-- Parameters
--   line:  The input to parse
--   command_table:  A table of parse instructions indexed by command
--
-- Return Values
--   rc:  Return code.  0 success, 1 incomplete, -1 error
--   cmd:   The command entry
--   parsed:  The parsed data
--   completions:  The set of possible completions if no error
--   str:  If rc==1: Description of next param. If rc==-1: what's wrong
--

function parse_line(line, command_table)
   local rc = 0
   local cmd, completions
   local str = ""
   local parsed = {}
   local orig_line = line

   ui_dbg_vverb("Parsing line %s\n", line)
   completions = get_keys_as_set(command_table)
   local s, e = line:find("%S+")
   if not s then
      return 1, nil, nil, completions, "Command required"
   end

   command = line:sub(s, e)
   line = line:sub(e+1)
   line = trim_string(line)

   command_entry = command_table[command]
   if not command_entry then
      completions, str = table_key_matches(completions, command)
      local count = set_card(completions)
      if count == 0 then
         return -1, nil, nil, nil, "Illegal command: " .. command
      end
      if count > 1 or line == "" then
         return 1, nil, nil, completions, ""
      end
      command = first_set_elt(completions)
      command_entry = command_table[command]
   end
   ui_dbg_vverb("parse_line: Found %s\n", command)
   completions = {}

   -- Okay, have a command entry; parse the rest of the line
   parse_tab = command_entry.parse_table
   parser = command_entry.parser
   if line ~= "" then
      completions = {}
      if parse_tab then
         rc, parsed, completions, str = parse_params(line, parse_tab)
         ui_dbg_vverb("parsed %d params: rc %d. cplts %d\n", set_card(parsed),
                      rc, set_card(completions))
      end
   elseif parse_tab and parse_tab[1] then
      if parse_tab[1].parser == parse_string_list then
         completions = get_values_as_set(parse_tab[1].pargs)
      end
   end

   if rc == 0 and parser then
      rc, parsed, completions, str = parser(command, orig_line, line, parsed)
      ui_dbg_vverb("top lvl parsed %d: rc %d. cplts %d\n", set_card(parsed),
                   rc, set_card(completions))
   end

   return rc, command_entry, parsed, completions, str
end


----------------------------------------------------------------
-- Core parsers; also used as validators for configuration values
--
-- function parse_<obj>(str, arg)
-- Usage:  pval, rest, completions = parse_foo(str, arg)
--    pval:  The parsed value or nil if failed
--    rest:  The unparsed portion of the linek
--    completions:  (Optional) What are valid completions if not successful
--
----------------------------------------------------------------

-- Parse and integer with optional min/max check
function parse_int(line, min_max)
   token, line = get_token(line)
   val = tonumber(token)

   if not val then return nil end

   local min = nil
   local max = nil

   if type(min_max) == "table" then
      min = min_max.min
      max = min_max.max
   end

   if min and val < min then 
      return nil
   end
   if max and val > max then 
      return nil
   end
   return val, line
end

-- Accept a string if it is in acceptable
-- Either keys or values may match
function parse_string_list(line, acceptable)
   token, line = get_token(line)
   local completions = nil
   if not token then
      completions = {}
      for k,v in pairs(acceptable) do
         if type(k) == "string" then completions[k] = true end
         if type(v) == "string" then completions[v] = true end
      end

      return nil, line, completions
   end
   for k,v in pairs(acceptable) do
      if token == k or token == v then
         return token, line
      end
      if type(k) == "string" and k:find("^" .. token) then
         completions = completions or {}
         completions[k] = true
      end
      if type(v) == "string" and v:find("^" .. token) then
         completions = completions or {}
         completions[v] = true
      end
   end

   return nil, line, completions
end

-- This is like parse_string_list, but accepts strings not in acceptable
-- Completions are only drawn from acceptable
function parse_any_string(line, acceptable)
   pval, newline, completions = parse_string_list(line, acceptable)
   if pval then return pval, newline end
   if set_card(completions) == 0 then -- Return token from original line
      return get_token(line)
   end
   return nil, newline, completions
end

-- return integer 1 or 0 for yes or no
function parse_yes_no(line, dflt)
   local y_vals = {"yes", "y", "1", "true"}
   local n_vals = {"no", "n", "0", "false"}
   local token

   token, line = get_token(line)
   if token then
      token = token:lower()
      if is_member(token, y_vals) then
         return 1, line
      end
      if is_member(token, n_vals) then
         return 0, line
      end
   else
      return nil, line, {yes = true, no = true}
   end

   if dflt then return dflt, line end
   return 0, line
end

-- Parse a port spec of the form 3,4-7,22,9-11
-- Return table with all values enumerated as integers or nil if error
function parse_port_spec(line, max)
   token, line = get_token(line)
   local out_tab = {}
   local low, high

   max = max or Global.port_count

   if not token then return nil, line end
   -- Get spec, first token
   local s, e = token:find("%S+")
   if not s then return nil, line end

   local spec = token:sub(s, e)
   local groups = {}

   -- Search for non number in string and return error
   if spec:find("[%a%c]") then return nil, line end
   -- TODO Search for non dash or comma punctuation in string and return error

   if spec:find(",") then
      groups = split(spec, ",") -- Split by , groups
   else
      groups[1] = spec
   end
   for i,v in ipairs(groups) do
      if v:find("-") then
         local range = split(v, "-")  -- Split low and high
         if #range ~= 2 then
            return nil, line
         end
         low = tonumber(range[1])
         high = tonumber(range[2])
      else
         if v:find("*") then
            if not max then return nil, line end
            low = 1
            high = max
         else
            low = tonumber(v)
            high = low
         end
      end
      -- TODO If max is defined, compare to high
      for i=low,high do
         table.insert(out_tab, i)
      end
   end

   return out_tab, line
end

function parse_dpid(line)
   local dpid, line = get_token(line)

   if string.find(dpid, "%X") or #dpid > 16 then
      return nil
   end
   return dpid, line
end

function parse_vid(line)
   local val, line = get_token(line)

   if not parse_int(val) then return nil end
   if tonumber(val) < -1 or tonumber(val) > 4095 then return nil end
   return val, line
end


function parse_mac(line)
   local mac, line = get_token(line)

   mac = string.lower(mac)
   local list = split(mac, ":")
   if #list ~= 6 then return nil, line end
   for i,v in ipairs(list) do
      if not tonumber(v, 16) then return nil end
      if tonumber(v, 16) < 0 or tonumber(v, 16) > 255 then return nil end
   end
   return mac, line
end

function parse_ip(line)
   local val, line = get_token(line)

   local count = 0
   for n in val:gmatch("%d+") do
      if not parse_int(n, {min=0,max=255}) then return nil end
      count = count + 1
   end
   if count ~= 4 then
      return nil, line
   end
   return val, line
end

-- Check if val is a hex number.  If max is given, ensure val <= max
-- Return val if valid, nil otherwise
function parse_hex(line, max)
   local val, line = get_token(line)

   if string.find(val, "%X") then return nil end
   if max == nil then return val, line end
   if tonumber("0x"..val) > max then return nil, line end

   return val, line
end

-- TODO: Allow range to be in multiple tokens
function parse_range(line)
   local val, line = get_token(line)

   r = split(val, "-")
   if #r ~= 2 then return nil, line end
   for i=1,2 do
      if not parse_int(r[i]) then return nil, line end
   end
   return val, line
end
