--[[
queue.lua keeps a minimal persistent FIFO using fskv for crash resilience.
It remains simple: pop returns the head, remove deletes it once confirmed.
--]]

local M = {}

local items = {}

local function generate_id()
    return "item-" .. os.time() .. "-" .. math.random(9999)
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

local function load_persisted()
    log.info("queue", "Loading messages from fskv")
    items = {}
    local iter = fskv.iter()
    while iter do
        local key = fskv.next(iter)
        if not key then break end
        if key:find("item-") then
            local chunk = fskv.get(key)
            if chunk then
                local ok, payload = pcall(json.decode, chunk)
                if ok and payload then
                    payload.retry = nil
                    table.insert(items, { id = key, payload = payload })
                else
                    log.warn("queue", "Bad payload for", key)
                end
            end
        end
    end
    log.info("queue", "Loaded", #items, "items")
end

function M.init()
    load_persisted()
end

function M.add(payload)
    local id = generate_id()
    if persist(id, payload) then
        table.insert(items, { id = id, payload = payload })
        log.info("queue", "Queued", id)
    end
end

function M.pop()
    local item = items[1]
    if not item then return nil end
    return item
end

function M.remove(id)
    for idx, item in ipairs(items) do
        if item.id == id then
            table.remove(items, idx)
            fskv.del(id)
            log.info("queue", "Removed", id)
            return
        end
    end
end

return M
