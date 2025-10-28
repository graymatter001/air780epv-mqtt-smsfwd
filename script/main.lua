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

if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end
socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "223.5.5.5")
mobile.setAuto(10000, 30000, 8, true, 60000)
fskv.init()

local phone_number = device.get_phone_number(config)

local current_message = nil
local sntp_started = false

local process_queue

local function on_publish_confirm(msg_id)
    if not current_message then return end
    local expected = current_message.msg_id
    if expected and msg_id and tostring(msg_id) ~= tostring(expected) then
        log.warn("main", "Ack id mismatch", msg_id, "expected", expected)
    end
    log.info("main", "Publish confirmed", msg_id)
    queue.remove(current_message.id)
    current_message = nil
end

local topics = mqtt_client.init(config.mqtt, phone_number, on_publish_confirm)

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

process_queue = function()
    if not mqtt_client.is_connected() then return end
    if current_message then return end

    local msg = queue.pop()
    if not msg then
        return
    end

    local payload = msg.payload
    local qos = payload.qos or 1
    local retain = payload.retain or false
    current_message = { id = msg.id }

    local result = mqtt_client.publish(payload.topic, payload.payload, qos, retain)

    if type(result) == "number" then
        current_message.msg_id = result
        return
    end

    if result == true or qos == 0 then
        queue.remove(current_message.id)
        current_message = nil
        return
    end

    log.warn("main", "Publish rejected, will retry", msg.id)
    current_message = nil
end

sys.subscribe("MQTT_DISCONNECTED", function()
    current_message = nil
end)

queue.init()

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

sys.taskInit(function()
    log.info("main", "Waiting for network connection...")
    local ready = sys.waitUntil("IP_READY", ip_ready_timeout)
    if ready then
        log.info("main", "Network is ready.")
    else
        log.warn("main", "IP_READY timeout, continuing")
    end

    if not sntp_started and config.sntp_interval and config.sntp_interval > 0 then
        if os.time() < 1714500000 then socket.sntp() end
        sys.timerLoopStart(socket.sntp, config.sntp_interval)
        sntp_started = true
    end

    mqtt_client.connect()
    sys.waitUntil("MQTT_CONNECTED", 60000)

    sys.timerLoopStart(process_queue, 1000)
end)

sys.run()
