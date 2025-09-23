--[[
device.lua
- Handles device-specific utilities like status reporting
--]]

local device = {}

-- Operator data for mapping IMSI to operator name
local oper_data = {
    ["46000"] = "CMCC", ["46002"] = "CMCC", ["46007"] = "CMCC", ["46008"] = "CMCC",
    ["46001"] = "CU",   ["46006"] = "CU",   ["46009"] = "CU",   ["46010"] = "CU",
    ["46003"] = "CT",   ["46005"] = "CT",   ["46011"] = "CT",   ["46012"] = "CT",
    ["46015"] = "CBN"
}

--- Gets the current status of the device.
-- @return A table with signal_strength, operator, and uptime.
function device.get_status()
    local context = require("context")
    -- Get Operator
    local imsi = mobile.imsi(mobile.simid()) or ""
    local mcc_mnc = string.sub(imsi, 1, 5)
    local operator = oper_data[mcc_mnc] or mcc_mnc

    -- Get Uptime
    local ms = mcu.ticks()
    local seconds = math.floor(ms / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    seconds = seconds % 60
    minutes = minutes % 60
    local uptime = string.format("%02d:%02d:%02d", hours, minutes, seconds)

    return {
        imei = mobile.imei(),
        iccid = mobile.iccid(),
        phone_number = context.phone_number,
        ip = socket.localIP(),
        signal_strength = mobile.rsrp(),
        operator = operator,
        uptime = uptime,
        timestamp = os.time()
    }
end

--- Attempts to recover the network connection by toggling flight mode.
function device.recover_network()
    log.warn("device.recover_network", "Attempting to recover network connection...")
    sys.taskInit(function()
        mobile.reset()
        sys.wait(1000)
        mobile.flymode(0, true)
        sys.wait(1000)
        mobile.flymode(0, false)
        log.info("device.recover_network", "Network recovery sequence complete.")
    end)
end

--- Gets the phone number from the SIM card or config.
-- @param config The application configuration table.
-- @return The phone number as a string.
function device.get_phone_number(config)
    local number = mobile.number()
    if number and number ~= "" then
        log.info("device.get_phone_number", "Got phone number from SIM:", number)
        return number
    else
        log.warn("device.get_phone_number", "Could not get phone number from SIM, using config fallback.")
        return config.phone_number
    end
end

return device