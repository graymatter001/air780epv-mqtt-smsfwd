return {
    init = function(opts)
        local queue, topics, phone_number = opts.queue, opts.topics, opts.phone_number
        local in_call, started_at = false, 0

        sys.subscribe("CC_IND", function(status)
            if status == "INCOMINGCALL" then
                if in_call then return end
                in_call, started_at = true, os.time()
                queue.add({
                    topic = topics.call_incoming,
                    payload = {
                        caller = cc.lastNum(),
                        recipient = phone_number,
                        timestamp = started_at
                    }
                })
                return
            end

            if status == "DISCONNECTED" and in_call then
                in_call = false
                local duration = math.max(0, os.time() - started_at)
                queue.add({
                    topic = topics.call_disconnected,
                    payload = {
                        caller = cc.lastNum(),
                        recipient = phone_number,
                        timestamp = os.time(),
                        duration = duration
                    }
                })
            end
        end)
    end
}
