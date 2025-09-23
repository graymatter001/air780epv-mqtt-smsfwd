--[[
call_handler.lua
- Handles incoming call events and forwards them via MQTT.
--]]

local call_handler = {}

--- Creates a new call handler instance.
-- @param queue A reference to the message queue.
-- @param mqtt_client A reference to the MQTT client.
-- @return A new handler object.
function call_handler.new(queue, mqtt_client)
    local context = require("context")
    local handler = {}
    handler.queue = queue
    handler.mqtt_client = mqtt_client
    handler.is_calling = false
    handler.call_start_time = 0

    --- Handles call events.
    -- This function is the callback for the "CC_IND" event.
    local function handle_call_event(status)
        if status == "INCOMINGCALL" then
            if handler.is_calling then return end
            handler.is_calling = true
            handler.call_start_time = os.time()
            log.info("call_handler", "Incoming call from:", cc.lastNum())
            handler.queue.add({
                topic = handler.mqtt_client.topics.call_incoming,
                payload = {
                    caller = cc.lastNum(),
                    recipient = context.phone_number,
                    timestamp = handler.call_start_time
                }
            })
        elseif status == "DISCONNECTED" then
            if not handler.is_calling then return end
            handler.is_calling = false
            local duration = math.floor(os.time() - handler.call_start_time + 0.5)
            log.info("call_handler", "Call disconnected from:", cc.lastNum(), "duration:", duration)
            handler.queue.add({
                topic = handler.mqtt_client.topics.call_disconnected,
                payload = {
                    caller = cc.lastNum(),
                    recipient = context.phone_number,
                    timestamp = os.time(),
                    duration = duration
                }
            })
        end
    end

    -- Subscribe to the system event for call indications
    sys.subscribe("CC_IND", handle_call_event)
    log.info("call_handler", "Call handler initialized and subscribed to CC_IND")

    return handler
end

return call_handler