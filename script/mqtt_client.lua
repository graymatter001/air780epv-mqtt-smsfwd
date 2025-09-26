--[[
mqtt_client.lua
- Manages the connection to the MQTT broker for publishing data.
--]]

local mqtt_client = {}
local device = require("device")
local context = require("context")

--- Creates a new MQTT client instance.
-- @return A new client object.
function mqtt_client.new()
    local client = {}
    client.config = context.config.mqtt
    client.mqttc = nil
    client.imei = mobile.imei()
    client.connected = false

    -- Define MQTT topics
    client.topics = {
        device_status = string.format("smsfwd/%s/device/status", client.imei),
        sms_incoming = string.format("smsfwd/%s/sms/incoming", client.imei),
        sms_status = string.format("smsfwd/%s/sms/status", client.imei),
        call_incoming = string.format("smsfwd/%s/call/incoming", client.imei),
        call_disconnected = string.format("smsfwd/%s/call/disconnected", client.imei)
    }

    --- Internal MQTT event handler.
    local function on_event(mqtt_client, event, data, payload)
        log.info("mqtt.on_event", "Event:", event, data)
        if event == "conack" then
            client.connected = true
            log.info("mqtt", "Connected to broker")
            sys.publish("MQTT_CONNECTED")
        elseif event == "disconnect" then
            client.connected = false
            log.info("mqtt", "Disconnected from broker")
            sys.publish("MQTT_DISCONNECTED")
        elseif event == "error" then
            log.error("mqtt.on_event", "MQTT error", data, payload)
        elseif event == "sent" then
            log.info("mqtt.on_event", "Message sent", data)
        end
    end

    --- Connects to the MQTT broker.
    function client.connect()
        client.mqttc = mqtt.create(nil, client.config.host, client.config.port, client.config.isssl)

        -- Set Last Will and Testament (LWT)
        local lwt_payload = json.encode({
            status = "offline",
            phone_number = context.phone_number,
            imei = client.imei,
            boot_time = os.time()
        })
        client.mqttc:will(client.topics.device_status, lwt_payload, 1, 1)

        client.mqttc:auth(client.imei, client.config.user, client.config.pass, false)
        client.mqttc:keepalive(client.config.keepalive)
        client.mqttc:autoreconn(true, 5000) -- Auto reconnect with 5s delay
        client.mqttc:on(on_event)
        client.mqttc:connect()
    end

    --- Publishes a message to a specific topic.
    -- @param topic The topic to publish to.
    -- @param payload The message payload (a Lua table).
    -- @param qos The Quality of Service level (0, 1, or 2).
    -- @return true if publishing was successful, false otherwise.
    function client.publish(topic, payload, qos, retain)
        if not client.connected or not client.mqttc then
            log.warn("mqtt.publish", "Not connected, cannot publish to", topic)
            return false
        end

        local json_payload = json.encode(payload)

        log.info("mqtt.publish", "Publishing to", topic)
        local msg_id = client.mqttc:publish(topic, json_payload, qos or 1, retain and 1 or 0)

        if not msg_id and (qos or 1) > 0 then
            log.warn("mqtt.publish", "Failed to publish message to", topic)
            return false
        end

        return true
    end

    --- Disconnects from the MQTT broker and releases resources.
    function client.disconnect()
        if client.mqttc then
            client.mqttc:close()
            client.mqttc = nil
            client.connected = false
            log.info("mqtt.disconnect", "MQTT client closed")
        end
    end

    return client
end

return mqtt_client