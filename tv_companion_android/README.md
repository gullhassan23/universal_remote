## TV Companion App (Scaffold)

This module is a foundation for a dedicated Android TV companion app that receives text payloads from the mobile remote app and dispatches them inside companion-controlled UI.

### Goals
- Deterministic voice/text handling without manual TV focus.
- Secure local protocol with app-level pairing token.
- Runtime fallback in mobile app to Android TV remote protocol when companion is unavailable.

### Current scaffold
- Protocol contract: `protocol/voice_input_schema.json`
- Android manifest with launcher + service declarations.
- Kotlin stubs for:
  - `CompanionInputService`
  - `CompanionInputActivity`
  - `CompanionProtocolServer`

### Next implementation steps
1. Start a local authenticated socket/WebSocket server in foreground service.
2. Verify signed token and message nonce/timestamp.
3. Route received text to companion UI input surfaces.
4. Send ack/error responses to mobile app.
