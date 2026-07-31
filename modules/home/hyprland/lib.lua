-- Helper functions for Hyprland Lua config
-- Based on end-4's lib/init.lua structure

HOME = os.getenv("HOME")

function is_file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then
      io.close(f)
      return true
   end
   return false
end

function create_if_not_exists(path)
   if not is_file_exists(path) then
      os.execute("mkdir -p \"$(dirname \"" .. path .. "\")\"")
      os.execute("echo '-- This file will not be overwritten across updates.' > \"" .. path .. "\"")
      return true
   end
   return false
end

function workspace_in_group(i)
    local curr = hl.get_active_workspace().id
    local newVal = math.floor((curr - 1) / workspaceGroupSize) * workspaceGroupSize + i
    return newVal
end

-- Launch first available program from a list
function launch_first_available(...)
    local apps = {...}
    for _, app in ipairs(apps) do
        -- Check if it's a command with arguments
        local cmd = app:match("^(%S+)")
        if os.execute("command -v " .. cmd .. " >/dev/null 2>&1") then
            return app
        end
    end
    -- Fallback to first app in list
    return apps[1]
end
