--[[
queue.lua keeps a minimal persistent FIFO using fskv for crash resilience.
It exposes functional helpers rather than constructors.
--]]

local M = {}

local messages = {}

local function generate_id()
    return "msg-" .. os.time() .. "-" .. math.random(9999)
end

local function load_persisted()
    log.info("queue", "Loading messages from fskv")
    messages = {}
    local iter = fskv.iter()
    while iter do
        local key = fskv.next(iter)
        if not key then break end
        if key:find("msg-") then
            local chunk = fskv.get(key)
            if chunk then
                local ok, payload = pcall(json.decode, chunk)
                if ok and payload then
                    table.insert(messages, { id = key, payload = payload, retry = payload.retry or 0 })
                else
                    log.warn("queue", "Bad payload for", key)
                end
            end
        end
    end
    log.info("queue", "Loaded", #messages, "messages")
end

function M.init()
    load_persisted()
end

local function persist(id, payload)
    local ok, encoded = pcall(json.encode, payload)
    if not ok then
        log.error("queue", "Encode failed", encoded)
        return false
    end
    if not fskv.set(id, encoded) then
        log.error("queue", "Persist failed", id)
        return false
    end
    return true
end

function M.add(payload)
    local id = generate_id()
    payload.retry = payload.retry or 0
    if persist(id, payload) then
        table.insert(messages, { id = id, payload = payload, retry = payload.retry })
        log.info("queue", "Queued", id)
    end
end

function M.pop()
    local message = messages[1]
    if not message then return nil end
    message.retry = message.retry + 1
    message.payload.retry = message.retry
    persist(message.id, message.payload)
    return message
end

function M.remove(id)
    for idx, message in ipairs(messages) do
        if message.id == id then
            table.remove(messages, idx)
            fskv.del(id)
            log.info("queue", "Removed", id)
            return
        end
    end
end

return M
