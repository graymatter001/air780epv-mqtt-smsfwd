local function enqueue(queue, topic, payload)
    queue.add({ topic = topic, payload = payload })
end

local function authorised(sender, whitelist)
    for _, number in ipairs(whitelist or {}) do
        if number == sender then return true end
    end
    return false
end

return {
    init = function(opts)
        local queue, topics, phone_number = opts.queue, opts.topics, opts.phone_number
        local whitelist = opts.whitelist

        sys.subscribe("SMS_INC", function(sender_number, sms_content)
            log.info("sms", "incoming", sender_number)

            if authorised(sender_number, whitelist) then
                local recipient, content = sms_content:match("^SMS,(%S+),(.+)$")
                if recipient and content then
                    local success = sms.send(recipient, content)
                    enqueue(queue, topics.sms_status, {
                        sender = phone_number,
                        recipient = recipient,
                        status = success and "delivered" or "failed",
                        timestamp = os.time()
                    })
                    return
                end
            end

            enqueue(queue, topics.sms_incoming, {
                sender = sender_number,
                recipient = phone_number,
                content = sms_content,
                timestamp = os.time()
            })
        end)
    end
}
