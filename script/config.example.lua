--[[
config.lua
- Contains all user-configurable settings
--]]

local config = {
    -- MQTT Broker Settings
    mqtt = {
        host = "",
        port = 8883,
        isssl = true,
        user = "",
        pass = "",
        keepalive = 120
    },

    -- Queue Settings
    queue = {
        max_retries = 20
    },

    -- SMS Control Settings
    sms_control = {
        -- A list of phone numbers authorized to send commands
        whitelist_numbers = {
            "00000000000"
        }
    },

    -- Time synchronization interval in milliseconds (e.g., 1 hour)
    sntp_interval = 3600000,

    -- The phone number of the SIM card in this device.
    -- This is used as a fallback if the number cannot be read from the SIM card directly.
    phone_number = "00000000000"
}

return config