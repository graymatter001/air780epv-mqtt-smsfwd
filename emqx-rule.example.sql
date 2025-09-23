SELECT
  CASE
    WHEN topic =~ 'smsfwd/+/sms/incoming' THEN sprintf('[~s] New SMS from ~s', (CASE WHEN strlen(payload.recipient) >= 4 THEN substr(payload.recipient, strlen(payload.recipient) - 4) ELSE payload.recipient END), payload.sender)
    WHEN topic =~ 'smsfwd/+/sms/status' THEN sprintf('[~s] SMS to ~s ~s', (CASE WHEN strlen(payload.sender) >= 4 THEN substr(payload.sender, strlen(payload.sender) - 4) ELSE payload.sender END), payload.recipient, payload.status)
    WHEN topic =~ 'smsfwd/+/call/incoming' THEN sprintf('[~s] Incoming call from ~s', (CASE WHEN strlen(payload.recipient) >= 4 THEN substr(payload.recipient, strlen(payload.recipient) - 4) ELSE payload.recipient END), payload.caller)
    WHEN topic =~ 'smsfwd/+/call/disconnected' THEN sprintf('[~s] Call ended with ~s', (CASE WHEN strlen(payload.recipient) >= 4 THEN substr(payload.recipient, strlen(payload.recipient) - 4) ELSE payload.recipient END), payload.caller)
    WHEN topic =~ 'smsfwd/+/device/status' AND payload.broadcast = true THEN sprintf('[~s] Device Online', (CASE WHEN strlen(payload.phone_number) >= 4 THEN substr(payload.phone_number, strlen(payload.phone_number) - 4) ELSE payload.phone_number END))
    WHEN topic =~ 'smsfwd/+/device/status' AND payload.status = 'offline' THEN sprintf('[~s] Device Offline', (CASE WHEN strlen(payload.phone_number) >= 4 THEN substr(payload.phone_number, strlen(payload.phone_number) - 4) ELSE payload.phone_number END))
    ELSE 'Unknown Notification'
  END as title,
  
  CASE
    WHEN topic =~ 'smsfwd/+/sms/incoming' THEN payload.content
    WHEN topic =~ 'smsfwd/+/sms/status' THEN sprintf('SMS from ~s to ~s was ~s.', payload.sender, payload.recipient, payload.status)
    WHEN topic =~ 'smsfwd/+/call/incoming' THEN sprintf('You have an incoming call from ~s', payload.caller)
    WHEN topic =~ 'smsfwd/+/call/disconnected' THEN sprintf('The call from ~s has ended after ~ps', payload.caller, payload.duration)
    WHEN topic =~ 'smsfwd/+/device/status' AND payload.broadcast = true THEN sprintf('Device with IMEI: ~s is now online. IP: ~s, Signal: ~p, Operator: ~s', payload.imei, payload.ip, payload.signal_strength, payload.operator)
    WHEN topic =~ 'smsfwd/+/device/status' AND payload.status = 'offline' THEN sprintf('Device with IMEI: ~s has gone offline. Booted at ~s', payload.imei, format_date('second', '+08:00', '%Y-%m-%d %H:%M:%S', payload.boot_time))
    ELSE 'Received an unhandled message.'
  END as body,

  CASE
    WHEN topic =~ 'smsfwd/+/sms/#' THEN 'https://img.icons8.com/?size=100&id=11411&format=png&color=000000'
    WHEN topic =~ 'smsfwd/+/call/#' THEN 'https://img.icons8.com/?size=100&id=9660&format=png&color=000000'
    WHEN topic =~ 'smsfwd/+/device/#' THEN 'https://img.icons8.com/?size=100&id=pqQPTtloE-E7&format=png&color=000000'
    ELSE ''
  END as icon,

  '' as device_key

FROM
  "smsfwd/#"
WHERE
  -- Ensure we only process messages that fit one of our expected patterns
  topic =~ 'smsfwd/+/sms/incoming' OR
  topic =~ 'smsfwd/+/sms/status' OR
  topic =~ 'smsfwd/+/call/incoming' OR
  topic =~ 'smsfwd/+/call/disconnected' OR
  (topic =~ 'smsfwd/+/device/status' AND payload.status = 'offline') OR
  (topic =~ 'smsfwd/+/device/status' AND payload.broadcast = true)
