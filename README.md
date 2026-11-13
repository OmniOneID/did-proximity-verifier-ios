# Proximity Verifier Guide

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg?style=flat)
[![Swift](https://img.shields.io/badge/Swift-5-orange.svg?style=flat)](https://developer.apple.com/swift)


## Overview
Proximity Verifier is an mdoc reader app based on ISO/IEC 18013-5. It reads a holder's mobile document (for example Personal Identification Data, PID) in person, verifies the issuer signature and device authentication, and shows the returned attributes.

- Device engagement by QR code scan or NFC tap
- Data retrieval over BLE (peripheral server or central client mode) or NFC, in the order set in Settings
- Request presets (Full / Custom) and per-attribute custom requests
- Trusted issuer list, with issuer keys resolved from DID Documents

Session handling and verification are done by the [mdoc Proximity SDK](https://github.com/OmniOneID/did-proximity-sdk-ios) (`MdocProximitySDK`).


## S/W Specifications
| Category         | Details                                         |
|------------------|-------------------------------------------------|
| OS               | iOS 17                                          |
| Language         | Swift 5                                         |
| UI Framework     | SwiftUI                                         |
| IDE              | Xcode 27.2                                      |
| Build System     | Xcode Basic build system                        |
| Compatibility    | iOS 17 or higher                                |
| Test Environment | iPhone Simulator and physical device            |

## Clone and checkout the Proximity Verifier project
```git
git clone https://github.com/OmniOneID/did-proximity-verifier-ios.git
```

The Xcode project lives under the `source` directory — open `source/ProximityVerifier.xcodeproj`.

## Folder Structure
```
did-proximity-verifier-ios
├── docs
├── sample
└── source
    ├── ProximityVerifier.xcodeproj
    ├── ProximityVerifier        # App sources
    │   ├── App                  # App entry, navigation, app model
    │   ├── DesignSystem         # Design tokens and UI primitives
    │   ├── Model                # Settings, requests, received credentials
    │   ├── Resources            # Assets and fonts
    │   ├── Screens              # Screens
    │   ├── Session              # Verification session (SDK / mock)
    │   ├── Support              # Icons, swipe-back gesture
    │   └── Trust                # Trusted issuer list, DID Document key resolution
    └── Config                   # Info.plist and entitlements (NFC)
```

## Build Method
How to compile and test your app using Xcode's default build system.
1. Install Xcode
    - Run Xcode and open the project file (.xcodeproj) by selecting File > Open from the top menu.
2. Open the project
    - When the project is opened, you can check the source files, resource files, and settings files in the Project Navigator on the left side of the Xcode window.
3. Select a simulator or actual device
    - At the top of the Xcode window, select the target device to build and run.
- Simulator: The UI runs, but BLE, NFC and the camera are not available. Use the mock session described below.
- Device: Required for an actual verification with a holder.

4. Check the project settings
    - Select the project file in the left project tree, and check Signing & Capabilities in the Target settings. A physical device build needs the **Near Field Communication Tag Reading** capability enabled for your App ID in the Apple Developer portal.

The same build from the command line:
```sh
xcodebuild -project source/ProximityVerifier.xcodeproj -scheme ProximityVerifier \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## SDK Application Method
The app uses the SDK as a Swift Package. The `MdocReader` product is already registered in the project, so Xcode resolves the package on first open and a fresh clone needs no manual step.

| Item       | Value                                                  |
|------------|--------------------------------------------------------|
| Package    | `https://github.com/OmniOneID/did-proximity-sdk-ios.git` |
| Dependency | Exact version `1.0.0` (tag `v1.0.0`)                   |
| Product    | `MdocReader` (`import MdocReader`)                      |

The resolved revision is pinned in `source/ProximityVerifier.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. To move to a newer SDK release, change the version under **Project → Package Dependencies** in Xcode.

Please refer to the SDK repository for its own license and dependencies.
<br>
[mdoc Proximity SDK License-dependencies](https://github.com/OmniOneID/did-proximity-sdk-ios/blob/main/dependencies-license.md)

## App Configuration

### NFC
NFC engagement and NFC data retrieval use `NFCTagReaderSession` with ISO 7816 tags. Two files under `source/Config/` hold the required settings.

| File | Key |
| --- | --- |
| `source/Config/ProximityVerifier.entitlements` | `com.apple.developer.nfc.readersession.formats` = `TAG` |
| `source/Config/Info.plist` | `com.apple.developer.nfc.readersession.iso7816.select-identifiers` |

Both AIDs must be registered, in this order:
1. `D2760000850101` — NFC Forum Type 4 Tag (engagement). It must come first, because the system stops at the first AID that answers.
2. `A0000002480400` — mdoc data retrieval. Without it, the SELECT for data retrieval is rejected.

### Trusted issuers
The trusted issuer list comes from the TAS list API (`GET /list/api/v1/mdoc/issuers`), and each listed issuer's DID Document comes from the API Gateway (`GET /api-gateway/api/v1/did-doc?did=...`). Both are downloaded together when **Refresh Trusted Issuers** is tapped and stored on the device; verification uses only the stored copies. An empty trusted issuer list rejects every issuer.

The two server addresses are set on the **Server URL** screen (Settings → Trusted Issuers → gear icon in the app bar). Each server is either Default (the build default) or Custom (a URL entered on the screen). A saved value applies to the next request without a restart, and if a save changes an effective URL, the stored trusted issuer list is cleared so it must be refreshed again.

| Server | Serves | Build default |
| --- | --- | --- |
| TAS | Trusted issuer list | `http://192.168.3.110:8090` |
| API Gateway | Issuer DID Document | `http://192.168.3.110:8093` |

The build defaults are development LAN servers over HTTP and are defined in `ServerEndpoint.defaultValue` (`source/ProximityVerifier/Trust/ServerURLStore.swift`); replace them with production addresses before release. HTTP is allowed by `NSAllowsArbitraryLoads` in `source/Config/Info.plist`, which also declares `NSLocalNetworkUsageDescription` for local network access.

### Run without a holder (DEBUG only)
Debug builds accept a launch argument that replaces the SDK session with sample data.
```sh
xcrun simctl launch <device> org.omnione.did.proximity.verifier -mock
```

## Change Log

ChangeLog can be found : 
<br>
- [Proximity Verifier iOS](CHANGELOG.md)  

## OpenDID Demonstration Videos <br>
To watch our demonstration videos of the OpenDID system in action, please visit our [Demo Repository](https://github.com/OmniOneID/did-demo-server). <br>

These videos showcase key features including user registration, VC issuance, and VP submission processes.

## Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details on our code of conduct, and the process for submitting pull requests to us.

## License
[Apache 2.0](LICENSE)
