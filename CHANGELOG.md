# Changelog

## v1.0.0 (2026-11-13)

### 🚀 New Features
- mdoc (ISO/IEC 18013-5) proximity verification on top of `MdocProximitySDK`
- Device engagement by QR code scan and by NFC tap (static handover)
- Data retrieval over BLE (peripheral server / central client mode) and NFC, in a user-defined transport order
- Request presets (Full / Custom) and per-attribute custom requests
- Trusted issuer list from the TAS list API (name and allowed docTypes per issuer), stored with each issuer's DID Document for offline issuer key resolution
- Server URL screen for the TAS and API Gateway addresses (Default / Custom per server), applied without a restart
- Received credential view with Issuer Trusted (issuer name, or the reason when not trusted), Device Auth and validity information
- Settings options: skip issuer verification, and BLE L2CAP use when available
