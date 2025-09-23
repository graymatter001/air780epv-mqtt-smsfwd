# Air780EPV MQTT SMS/Call Forwarder

This project is a Lua-based firmware for the Air780EPV module that forwards SMS messages and call notifications to an MQTT broker. It also allows for remote control via SMS commands and provides device status monitoring.

## Features

- **SMS Forwarding**: Forwards incoming SMS messages to a specified MQTT topic.
- **Call Notifications**: Sends notifications for incoming and disconnected calls to MQTT topics.
- **Remote SMS Sending**: Send SMS messages from the device by sending a command from a whitelisted phone number.
- **Device Status**: Periodically publishes device status (signal strength, operator, uptime, etc.) to an MQTT topic.
- **Persistent Queue**: Messages are stored in a persistent queue to prevent loss if the device is offline.
- **Reliability**: Includes a watchdog timer and automatic network recovery.

## Configuration

To use this firmware, you need to configure your settings in `script/config.lua`. A `script/config.example.lua` is provided as a template.

## EMQX Rule for Bark Notifications

The `emqx-rule.example.sql` file contains a pre-configured rule for EMQX that transforms the MQTT messages from this device into formatted push notifications for the [Bark](https://github.com/Finb/Bark) app.

### Features of the Rule

- **Human-Readable Titles**: Generates clear titles like "New SMS from..." or "Incoming call from...".
- **Informative Body**: Provides the full content of the SMS or details about the call.
- **Contextual Icons**: Assigns icons based on the type of notification (SMS, call, or device status).
- **Device Filtering**: The rule is designed to only process messages from this firmware.

To use this rule, you will need to set up a Webhook sink in your EMQX dashboard and import the SQL from `emqx-rule.sql`. Make sure to replace the placeholder `device_key` with your actual Bark device key.

## MQTT Topics

The firmware uses the following MQTT topic structure, where `[imei]` is the IMEI of your device:

- **Device Status**: `smsfwd/[imei]/device/status`
- **Incoming SMS**: `smsfwd/[imei]/sms/incoming`
- **Outgoing SMS Status**: `smsfwd/[imei]/sms/status`
- **Incoming Call**: `smsfwd/[imei]/call/incoming`
- **Call Disconnected**: `smsfwd/[imei]/call/disconnected`

## SMS Commands

To send an SMS from the device, send an SMS from a whitelisted number with the following format:

`SMS,[recipient_phone_number],[message_content]`

Example: `SMS,1234567890,Hello from the device!`

## References

The `references` directory contains additional documentation, including the LuatOS API documentation, Bark API details, and other related projects (for strange reasons some of them disappeared).

Special thanks to

- [gaoyifan/AirRelay: 📨 一个基于合宙Air780E的短信转发工具，支持通过Telegram实时收发短信。](https://github.com/gaoyifan/AirRelay)
- [lageev/air780e-forwarder: Air780E / Air780EG 短信转发 (不支持电信卡), 完美支持 Air700E (移动卡Only)](https://github.com/lageev/air780e-forwarder)
