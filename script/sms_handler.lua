local M = {}

local function is_whitelisted(number, whitelist)
    for _, entry in ipairs(whitelist or {}) do
        if entry == number then return true end
    end
    return false
end

local function enqueue(queue, topics, payload)
    queue.add({ topic = topics.sms_incoming, payload = payload })
end

local function enqueue_status(queue, topics, payload)
    queue.add({ topic = topics.sms_status, payload = payload })
end

function M.init(opts)
    local queue = opts.queue
    local topics = opts.topics
    local phone_number = opts.phone_number
    local whitelist = opts.whitelist

    local function handle_incoming_sms(sender_number, sms_content)
        log.info("sms", "incoming", sender_number)

        if is_whitelisted(sender_number, whitelist) then
            local recipient, content = sms_content:match("^SMS,(%S+),(.+)$")
            if recipient and content then
                local success = sms.send(recipient, content)
                enqueue_status(queue, topics, {
                    sender = phone_number,
                    recipient = recipient,
                    status = success and "delivered" or "failed",
                    timestamp = os.time()
                })
                return
            end
        end

        enqueue(queue, topics, {
            sender = sender_number,
            recipient = phone_number,
            content = sms_content,
            timestamp = os.time()
        })
    end

    sys.subscribe("SMS_INC", handle_incoming_sms)
end

return M
