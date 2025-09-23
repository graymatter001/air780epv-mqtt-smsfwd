--[[
queue.lua
- Manages a generic, persistent message queue using fskv
--]]

local queue = {}

-- Private function to generate a unique message ID
local function generate_id()
    return "msg-t" .. os.time() .. "r" .. math.random(9999)
end

--- Creates a new queue instance.
-- @return A new queue object.
function queue.new()
    local q = {}
    q.messages = {} -- In-memory queue, stores messages as {id, payload, retry}

    -- Load existing messages from fskv on startup
    log.info("queue", "Loading existing messages from fskv")
    local iter = fskv.iter()
    while iter do
        local k = fskv.next(iter)
        if not k then
            break
        end
        -- Ensure we only load keys with our message prefix
        if string.find(k, "msg-") then
            local v = fskv.get(k)
            if v then
                local success, payload = pcall(json.decode, v)
                if success and payload then
                    table.insert(q.messages, { id = k, payload = payload, retry = payload.retry or 0 })
                    log.info("queue", "Loaded message from fskv:", k)
                else
                    log.warn("queue", "Failed to decode message from fskv:", k)
                end
            end
        end
    end
    log.info("queue", "Loaded", #q.messages, "messages from fskv")

    --- Adds a message to the queue.
    -- @param payload The message payload (a Lua table).
    function q.add(payload)
        local id = generate_id()
        payload.retry = payload.retry or 0
        local message = { id = id, payload = payload, retry = payload.retry }

        local success, encoded_payload = pcall(json.encode, payload)
        if not success then
            log.error("queue.add", "Failed to encode payload for fskv", encoded_payload)
            return
        end

        local result = fskv.set(id, encoded_payload)
        if result then
            table.insert(q.messages, message)
            log.info("queue.add", "Message added to queue and fskv", id)
        else
            log.error("queue.add", "Failed to save message to fskv", id)
        end
    end

    --- Retrieves the next message from the queue for processing.
    -- It does not remove the message; call remove() after successful processing.
    -- @return The next message object or nil if the queue is empty.
    function q.pop()
        if #q.messages > 0 then
            local message = q.messages[1]
            message.retry = message.retry + 1
            message.payload.retry = message.retry
            -- Update the retry count in fskv
            fskv.set(message.id, json.encode(message.payload))
            return message
        end
        return nil
    end

    --- Removes a message from the queue and fskv.
    -- @param id The unique ID of the message to remove.
    function q.remove(id)
        for i, message in ipairs(q.messages) do
            if message.id == id then
                table.remove(q.messages, i)
                fskv.del(id)
                log.info("queue.remove", "Message removed from queue and fskv", id)
                return
            end
        end
    end

    return q
end

return queue