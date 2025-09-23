# When writing EMQX SQL to transform data for Bark

1. **Understand the Payload**: Before writing any SQL, inspect other files to understand the structure of the incoming MQTT payload. This will help you extract the correct fields for the Bark message.

2. **Consult the Bark API Documentation**: Refer to [`references/bark-api.md`](references/bark-api.md) to understand the expected format and available parameters for Bark messages. This includes parameters like `title`, `body`, `sound`, `icon`, and more.

3. **Construct a Clear and Informative Message**:
    * **Title**: The title should clearly indicate the source or purpose of the message. For example, instead of just using the sender's number, use a more descriptive title like "New SMS from [Sender]".
    * **Body**: The body should contain the main content of the message. Include all relevant information from the payload.
    * **Icon**: Use the `icon` parameter to provide immediate visual context. For example, use an SMS icon for text messages or a phone icon for missed calls. This helps users quickly identify the type of notification.
    * **Context**: If possible, provide additional context in the message body. For example, if the message is an alert, mention what triggered it.

4. **Consider the User Experience**: Think about how the user will receive and interpret the notification. Avoid using ambiguous titles or sending incomplete information. The goal is to provide a notification that is immediately understandable and actionable.
