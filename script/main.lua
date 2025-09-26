--[[
main.lua
- Initializes all modules
- Starts the main application logic
--]]

-- LuaTools needs PROJECT and VERSION information
PROJECT = "mqtt_sms_forwarder"
VERSION = "1.0.0"

log.setLevel("DEBUG")
log.info("main", PROJECT, VERSION)
log.info("main", "Boot reason", pm.lastReson())

-- Import required libraries
sys = require("sys")
sysplus = require("sysplus")

-- Load application modules
local config = require("config")
local context = require("context")
local queue = require("queue")
local device = require("device")
local mqtt_client = require("mqtt_client")
local sms_handler = require("sms_handler")
local call_handler = require("call_handler")

-- System Initialization
if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end
socket.setDNS(nil, 1, "119.29.29.29")
socket.setDNS(nil, 2, "223.5.5.5")
-- Enable automatic network recovery
mobile.setAuto(10000, 30000, 8, true, 60000)
fskv.init()

-- Instantiate modules
local msg_queue = queue.new()
context.init({
    config = config,
    phone_number = device.get_phone_number(config)
})
local mq_client = mqtt_client.new()
sms_handler.new(msg_queue, mq_client)
call_handler.new(msg_queue, mq_client)

-- Publish retained 'online' status on each MQTT connect (queued for reliability)
sys.subscribe("MQTT_CONNECTED", function()
    local status_payload = device.get_status()
    status_payload.status = "online"
    status_payload.broadcast = true
    msg_queue.add({
        topic = mq_client.topics.device_status,
        payload = status_payload,
        qos = 1,
        retain = true
    })
end)
-- Main application task

--- Publishes the device status to the MQTT broker.
-- @param broadcast boolean If true, the message will be marked for forwarding.
local function publish_device_status(broadcast)
    local status_payload = device.get_status()
    if broadcast then
        status_payload.broadcast = true
    end
    msg_queue.add({
        topic = mq_client.topics.device_status,
        payload = status_payload
    })
end

--- Processes all messages in the queue until it is empty.
local is_processing_queue = false
local error_count = 0
local function process_queue()
    -- This flag prevents re-entry if the function is called again while it's already running
    if is_processing_queue then return end
    is_processing_queue = true

    -- Only process when MQTT is connected to avoid inflating retries while offline
    if not mq_client.connected then
        is_processing_queue = false
        return
    end

    local msg = msg_queue.pop()

    if msg then
        log.info("main", "Processing message from queue:", msg.id)

        if msg.retry > config.queue.max_retries then
            log.warn("main", "Message exceeded max retries, discarding:", msg.id)
            msg_queue.remove(msg.id)
        else
            local success = mq_client.publish(msg.payload.topic, msg.payload.payload, msg.payload.qos or 1, msg.payload.retain or false)
            if success then
                log.info("main", "Message published successfully:", msg.id)
                msg_queue.remove(msg.id)
                error_count = 0 -- Reset error count on success
            else
                log.warn("main", "Failed to publish message, will retry:", msg.id)
                error_count = error_count + 1
                if error_count >= 3 then
                    device.recover_network()
                    error_count = 0
                end
            end
        end
    end

    is_processing_queue = false
end

sys.taskInit(function()
    log.info("main", "Waiting for network connection...")
    sys.waitUntil("IP_READY", 120000) -- 2 minute timeout
    log.info("main", "Network is ready.")

    -- Sync time with NTP server
    if config.sntp_interval and config.sntp_interval > 0 then
        if os.time() < 1714500000 then
            socket.sntp()
        end
        sys.timerLoopStart(socket.sntp, config.sntp_interval)
    end

    -- Connect MQTT client
    mq_client.connect()

    -- Wait for MQTT connection before starting queue processing
    sys.waitUntil("MQTT_CONNECTED", 60000)

    -- Initial online message is queued on MQTT_CONNECTED event; no direct send here

    -- Periodically publish device status (heartbeat)
    sys.timerLoopStart(function()
        publish_device_status(false)
    end, 60000) -- Every 60 seconds

    -- Periodically process the message queue
    sys.timerLoopStart(process_queue, 1000) -- Every 1 second
end)

sys.run()