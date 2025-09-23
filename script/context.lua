--[[
context.lua
- Holds the shared application context, such as configuration and device state.
--]]

local context = {}

--- Initializes the application context.
-- This should be called once at startup.
-- @param initial_context A table containing the initial context values.
function context.init(initial_context)
    for k, v in pairs(initial_context) do
        context[k] = v
    end
    log.info("context", "Application context initialized")
end

return context