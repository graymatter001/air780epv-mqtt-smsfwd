--[[
main.lua wires together the bare minimum needed to push events to MQTT.
Heavy abstractions just added clutter, so the orchestration now lives here.
--]]

PROJECT = "mqtt_sms_forwarder"
VERSION = "1.0.0"

log.setLevel("DEBUG")
log.info("main", PROJECT, VERSION)
log.info("main", "Boot reason", pm.lastReson())

sys = require("sys")
sysplus = require("sysplus")

local config = require("config")
local queue = require("queue")
local device = require("device")
local mqtt_client = require("mqtt_client")
local sms_handler = require("sms_handler")
local call_handler = require("call_handler")

if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end
socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "223.5.5.5")
mobile.setAuto(10000, 30000, 8, true, 60000)
fskv.init()

local phone_number = device.get_phone_number(config)
queue.init()
local topics = mqtt_client.init(config.mqtt, phone_number)

sms_handler.init({
    queue = queue,
    topics = topics,
    phone_number = phone_number,
    whitelist = config.sms_control.whitelist_numbers
})

call_handler.init({
    queue = queue,
    topics = topics,
    phone_number = phone_number
})

sys.subscribe("MQTT_CONNECTED", function()
    local status = device.get_status(phone_number)
    status.status = "online"
    status.broadcast = true
    queue.add({
        topic = topics.device_status,
        payload = status,
        qos = 1,
        retain = true
    })
end)

local function publish_device_status(broadcast)
    local status = device.get_status(phone_number)
    if broadcast then status.broadcast = true end
    queue.add({
        topic = topics.device_status,
        payload = status
    })
end

local is_processing_queue = false
local error_count = 0
local function process_queue()
    if is_processing_queue then return end
    is_processing_queue = true

    if not mqtt_client.is_connected() then
        is_processing_queue = false
        return
    end

    local msg = queue.pop()
    if not msg then
        is_processing_queue = false
        return
    end

    log.info("main", "Processing message from queue:", msg.id)

    if msg.retry > config.queue.max_retries then
        log.warn("main", "Message exceeded max retries, discarding:", msg.id)
        queue.remove(msg.id)
        is_processing_queue = false
        return
    end

    local payload = msg.payload
    local ok = mqtt_client.publish(payload.topic, payload.payload, payload.qos or 1, payload.retain or false)
    if ok then
        log.info("main", "Published queue message:", msg.id)
        queue.remove(msg.id)
        error_count = 0
    else
        log.warn("main", "Publish failed, will retry:", msg.id)
        error_count = error_count + 1
        if error_count >= 3 then
            device.recover_network()
            error_count = 0
        end
    end

    is_processing_queue = false
end

sys.taskInit(function()
    log.info("main", "Waiting for network connection...")
    sys.waitUntil("IP_READY", 120000)
    log.info("main", "Network is ready.")

    if config.sntp_interval and config.sntp_interval > 0 then
        if os.time() < 1714500000 then socket.sntp() end
        sys.timerLoopStart(socket.sntp, config.sntp_interval)
    end

    mqtt_client.connect()
    sys.waitUntil("MQTT_CONNECTED", 60000)

    sys.timerLoopStart(function() publish_device_status(false) end, 60000)
    sys.timerLoopStart(process_queue, 1000)
end)

sys.run()
