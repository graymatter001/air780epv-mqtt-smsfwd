--[[
sms_handler.lua
- Handles incoming SMS, parsing for commands and forwarding regular messages.
--]]

local sms_handler = {}

--- Checks if a value exists in a table.
-- @param tbl The table to search in.
-- @param val The value to search for.
-- @return true if the value is found, false otherwise.
local function is_in_table(tbl, val)
    for _, value in ipairs(tbl) do
        if value == val then
            return true
        end
    end
    return false
end

--- Creates a new SMS handler instance.
-- @param queue A reference to the message queue.
-- @param mqtt_client A reference to the MQTT client.
-- @return A new handler object.
function sms_handler.new(queue, mqtt_client)
    local context = require("context")
    local handler = {}
    handler.config = context.config
    handler.queue = queue
    handler.mqtt_client = mqtt_client

    --- Handles an incoming SMS message.
    -- This function is the callback for the "SMS_INC" event.
    -- @param sender_number The phone number of the sender.
    -- @param sms_content The text content of the SMS.
    local function handle_incoming_sms(sender_number, sms_content)
        log.info("sms_handler", "Received SMS from:", sender_number)

        local is_command = false
        -- Check if the sender is in the whitelist
        if is_in_table(handler.config.sms_control.whitelist_numbers, sender_number) then
            -- Try to parse a command from the SMS content
            local recipient, content_to_send = sms_content:match("^SMS,(%S+),(.+)$")
            if recipient and content_to_send then
                is_command = true
                log.info("sms_handler", "SMS command received. Sending SMS to:", recipient)
                local success = sms.send(recipient, content_to_send)

                -- Queue a status message to be sent via MQTT
                local status_payload = {
                    sender = context.phone_number,
                    recipient = recipient,
                    status = success and "delivered" or "failed",
                    timestamp = os.time()
                }
                handler.queue.add({
                    topic = handler.mqtt_client.topics.sms_status,
                    payload = status_payload
                })
            end
        end

        -- If it was not a command, forward the original SMS via MQTT
        if not is_command then
            log.info("sms_handler", "Forwarding regular SMS to MQTT")
            local forward_payload = {
                sender = sender_number,
                recipient = context.phone_number,
                content = sms_content,
                timestamp = os.time()
            }
            handler.queue.add({
                topic = handler.mqtt_client.topics.sms_incoming,
                payload = forward_payload
            })
        end
    end

    -- Subscribe to the system event for incoming SMS
    sys.subscribe("SMS_INC", handle_incoming_sms)
    log.info("sms_handler", "SMS handler initialized and subscribed to SMS_INC")

    return handler
end

return sms_handler