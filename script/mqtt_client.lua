local M = {}

local connection = { mqttc = nil, topics = {}, connected = false }

local function build_topics(imei)
    return {
        device_status = string.format("smsfwd/%s/device/status", imei),
        sms_incoming = string.format("smsfwd/%s/sms/incoming", imei),
        sms_status = string.format("smsfwd/%s/sms/status", imei),
        call_incoming = string.format("smsfwd/%s/call/incoming", imei),
        call_disconnected = string.format("smsfwd/%s/call/disconnected", imei)
    }
end

local function on_event(_, event, data, payload)
    log.info("mqtt", "event", event, data)
    if event == "conack" then
        connection.connected = true
        sys.publish("MQTT_CONNECTED")
    elseif event == "disconnect" then
        connection.connected = false
        sys.publish("MQTT_DISCONNECTED")
    elseif event == "error" then
        log.error("mqtt", "error", data, payload)
    end
end

function M.init(mqtt_config, phone_number)
    local imei = mobile.imei()
    connection.topics = build_topics(imei)
    connection.phone_number = phone_number
    connection.cfg = mqtt_config
    connection.imei = imei
    return connection.topics
end

function M.connect()
    local cfg = connection.cfg
    connection.mqttc = mqtt.create(nil, cfg.host, cfg.port, cfg.isssl)

    local lwt_payload = json.encode({
        status = "offline",
        phone_number = connection.phone_number,
        imei = connection.imei,
        boot_time = os.time()
    })
    connection.mqttc:will(connection.topics.device_status, lwt_payload, 1, 1)
    connection.mqttc:auth(connection.imei, cfg.user, cfg.pass, false)
    connection.mqttc:keepalive(cfg.keepalive)
    connection.mqttc:autoreconn(true, 5000)
    connection.mqttc:on(on_event)
    connection.mqttc:connect()
end

function M.publish(topic, payload, qos, retain)
    if not connection.connected or not connection.mqttc then
        return false
    end
    local json_payload = json.encode(payload)
    local msg_id = connection.mqttc:publish(topic, json_payload, qos or 1, retain and 1 or 0)
    if not msg_id and (qos or 1) > 0 then
        return false
    end
    return true
end

function M.disconnect()
    if connection.mqttc then
        connection.mqttc:close()
        connection.mqttc = nil
        connection.connected = false
    end
end

function M.is_connected()
    return connection.connected
end

return M
