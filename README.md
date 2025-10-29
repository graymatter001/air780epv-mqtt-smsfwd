# Air780EPV MQTT SMS/Call Forwarder

Firmware for the Air780EP/EPV that forwards SMS and call events to MQTT, keeps device status online, and lets trusted numbers trigger outbound SMS.

## Setup

1. Copy `script/config.example.lua` to `script/config.lua`.
2. Fill in MQTT host, credentials, `whitelist_numbers`, optional `sntp_interval`, and fallback `phone_number`.
3. Package the `script/` directory with Luatools (or similar) and flash it to the module.
4. Power on with a SIM card; the modem connects, syncs time if enabled, restores queued payloads from `fskv`, and starts publishing.

*Firmware note:* the project targets LuatOS v1002, the latest vendor image confirmed to ship with the `mqtt` module. Some community-shared cloud-compiled v2001+ builds floating around omit `mqtt`, so stick with v1002 unless you verify the module is present.

## MQTT Topics

Replace `[imei]` with the modem IMEI; payloads are JSON.

- `smsfwd/[imei]/device/status` — retained heartbeat with metrics and online/offline state.
- `smsfwd/[imei]/sms/incoming` — inbound SMS content.
- `smsfwd/[imei]/sms/status` — delivery result for outbound commands.
- `smsfwd/[imei]/call/incoming` — ringing events.
- `smsfwd/[imei]/call/disconnected` — hang-up events with duration where known.

### Remote SMS Command

Send from a whitelisted number:

```
SMS,<recipient>,<message>
```

The publish will appear on `sms/status` with `delivered` or `failed`.

## Bark Notifications (EMQX)

`emqx-rule.example.sql` shows how to turn the MQTT payloads into Bark pushes with clear titles, detailed bodies, and per-event icons. Import it (or your own copy) into EMQX, point it at a Bark Webhook sink, and replace the placeholder `device_key`. Check `references/bark-api.md` for payload limits before tweaking the SQL.

## Repo Notes

- Core modules live in `script/`: `main.lua`, `queue.lua`, `mqtt_client.lua`, `sms_handler.lua`, and `call_handler.lua`.
- `queue.lua` stores unsent messages in `fskv` so publishes survive reboots.
- LuatOS API docs and Bark references sit under `references/`.

## Thanks

- [gaoyifan/AirRelay](https://github.com/gaoyifan/AirRelay)
- [lageev/air780e-forwarder](https://github.com/lageev/air780e-forwarder)
