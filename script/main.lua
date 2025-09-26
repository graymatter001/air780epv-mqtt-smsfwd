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

local ip_ready_timeout = 120000
local max_ip_attempts = 3
local post_recover_delay = 10000
local mqtt_disconnect_threshold = 3
local mqtt_recovery_backoff = 60000

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

local inflight = {}
local sntp_started = false

local function on_publish_confirm(msg_id)
    local message = inflight[msg_id]
    if not message then return end
    log.info("main", "Publish confirmed", msg_id)
    queue.remove(message.id)
    inflight[msg_id] = nil
    sys.publish("QUEUE_WAKE")
end

local topics = mqtt_client.init(config.mqtt, phone_number, on_publish_confirm)

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
    mqtt_disconnects = 0
    local status = device.get_status(phone_number)
    status.status = "online"
    status.broadcast = true
    queue.add({
        topic = topics.device_status,
        payload = status,
        qos = 1,
        retain = true
    })
    sys.publish("QUEUE_WAKE")
end)

local function publish_device_status(broadcast)
    local status = device.get_status(phone_number)
    if broadcast then status.broadcast = true end
    queue.add({
        topic = topics.device_status,
        payload = status
    })
end

local function reset_inflight()
    for msg_id in pairs(inflight) do
        inflight[msg_id] = nil
    end
end

local processing = false
local ip_attempts = 0
local mqtt_disconnects = 0
local last_mqtt_recover = 0
local function process_queue()
    if processing then return end
    if not mqtt_client.is_connected() then return end
    if next(inflight) then return end

    processing = true

    local msg = queue.pop()
    if not msg then
        processing = false
        return
    end

    if msg.retry > config.queue.max_retries then
        log.warn("main", "Max retries reached, dropping", msg.id)
        queue.remove(msg.id)
        processing = false
        sys.publish("QUEUE_WAKE")
        return
    end

    local payload = msg.payload
    local qos = payload.qos or 1
    local result = mqtt_client.publish(payload.topic, payload.payload, qos, payload.retain or false)

    if type(result) == "number" then
        inflight[result] = msg
    elseif result == true or qos == 0 then
        queue.remove(msg.id)
        sys.publish("QUEUE_WAKE")
    else
        log.warn("main", "Publish rejected, will retry", msg.id)
        sys.timerStart(process_queue, 2000)
    end

    processing = false
end

sys.subscribe("QUEUE_WAKE", function()
    process_queue()
end)

sys.subscribe("MQTT_DISCONNECTED", function()
    reset_inflight()
    mqtt_disconnects = mqtt_disconnects + 1
    local now = mcu.ticks()
    if mqtt_disconnects >= mqtt_disconnect_threshold then
        if now - last_mqtt_recover >= mqtt_recovery_backoff then
            if device.recover_network("mqtt disconnect") then
                last_mqtt_recover = now
            end
        else
            log.info("main", "Recovery backoff active, skipping")
        end
        mqtt_disconnects = 0
    end
    sys.publish("QUEUE_WAKE")
end)

sys.taskInit(function()
    log.info("main", "Waiting for network connection...")
    while ip_attempts < max_ip_attempts do
        local ready = sys.waitUntil("IP_READY", ip_ready_timeout)
        if ready then
            log.info("main", "Network is ready.")
            ip_attempts = 0
            break
        end

        ip_attempts = ip_attempts + 1
        log.warn("main", "IP_READY timed out", ip_attempts, "of", max_ip_attempts)
        if device.recover_network("ip timeout") then
            sys.wait(post_recover_delay)
        end
    end

    if ip_attempts >= max_ip_attempts then
        log.error("main", "Unable to obtain IP address after attempts", max_ip_attempts)
        if rtos and rtos.reboot then
            log.error("main", "Rebooting due to network recovery exhaustion")
            rtos.reboot()
        end
        return
    end

    if not sntp_started and config.sntp_interval and config.sntp_interval > 0 then
        if os.time() < 1714500000 then socket.sntp() end
        sys.timerLoopStart(socket.sntp, config.sntp_interval)
        sntp_started = true
    end

    mqtt_client.connect()
    sys.waitUntil("MQTT_CONNECTED", 60000)

    sys.timerLoopStart(function()
        publish_device_status(false)
    end, 60000)

    sys.timerLoopStart(process_queue, 1000)
end)

sys.run()
