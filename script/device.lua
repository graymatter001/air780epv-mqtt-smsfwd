--[[
device.lua
- Handles device-specific utilities like status reporting
--]]

local device = {}

local oper_data = {
    ["46000"] = "CMCC", ["46002"] = "CMCC", ["46007"] = "CMCC", ["46008"] = "CMCC",
    ["46001"] = "CU",   ["46006"] = "CU",   ["46009"] = "CU",   ["46010"] = "CU",
    ["46003"] = "CT",   ["46005"] = "CT",   ["46011"] = "CT",   ["46012"] = "CT",
    ["46015"] = "CBN"
}

local recovering = false

local function operator_name()
    local imsi = mobile.imsi(mobile.simid()) or ""
    local mcc_mnc = string.sub(imsi, 1, 5)
    return oper_data[mcc_mnc] or mcc_mnc
end

local function uptime_hms()
    local seconds = math.floor(mcu.ticks() / 1000)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    seconds = seconds % 60
    minutes = minutes % 60
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function device.get_status(phone_number)
    return {
        imei = mobile.imei(),
        iccid = mobile.iccid(),
        phone_number = phone_number,
        ip = socket.localIP(),
        signal_strength = mobile.rsrp(),
        operator = operator_name(),
        uptime = uptime_hms(),
        timestamp = os.time()
    }
end

--- Attempts to recover the network connection by toggling flight mode.
function device.recover_network(reason)
    if recovering then
        log.info("device.recover_network", "Recovery already in progress", reason or "")
        return false
    end

    recovering = true
    sys.taskInit(function()
        log.warn("device.recover_network", "Attempting to recover network connection...", reason or "")
        mobile.reset()
        sys.wait(1000)
        mobile.flymode(0, true)
        sys.wait(1000)
        mobile.flymode(0, false)
        log.info("device.recover_network", "Network recovery sequence complete.")
        recovering = false
    end)

    return true
end

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
