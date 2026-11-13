# Proximity Verifier Guide

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg?style=flat)
[![Swift](https://img.shields.io/badge/Swift-5-orange.svg?style=flat)](https://developer.apple.com/swift)


## 개요
Proximity Verifier 는 ISO/IEC 18013-5 기반 mdoc 리더 앱입니다. 홀더의 모바일 신분증(예: 신원 증명 데이터 PID)을 대면으로 읽어 발급자 서명과 기기 인증을 검증하고, 돌려받은 속성을 보여 줍니다.

- QR 코드 스캔 또는 NFC 태그로 device engagement
- 설정에서 정한 순서에 따라 BLE(peripheral server 또는 central client 모드) 또는 NFC 로 데이터 수신
- 요청 프리셋(Full / Custom)과 속성 단위 사용자 지정 요청
- 신뢰 발급자 목록, DID Document 기반 발급자 키 조회

세션 처리와 검증은 [mdoc Proximity SDK](https://github.com/OmniOneID/did-proximity-sdk-ios) (`MdocProximitySDK`)가 담당합니다.


## S/W 사양
| 구분             | 내용                                            |
|------------------|-------------------------------------------------|
| OS               | iOS 17                                          |
| Language         | Swift 5                                         |
| UI Framework     | SwiftUI                                         |
| IDE              | Xcode 27.2                                      |
| Build System     | Xcode 기본 빌드 시스템                          |
| Compatibility    | iOS 17 이상                                     |
| Test Environment | iPhone 시뮬레이터 및 실기기                     |

## Proximity Verifier 프로젝트 클론 및 체크아웃
```git
git clone https://github.com/OmniOneID/did-proximity-verifier-ios.git
```

Xcode 프로젝트는 `source` 디렉터리 아래에 있습니다. `source/ProximityVerifier.xcodeproj` 를 엽니다.

## 폴더 구조
```
did-proximity-verifier-ios
├── docs
├── sample
└── source
    ├── ProximityVerifier.xcodeproj
    ├── ProximityVerifier        # 앱 소스
    │   ├── App                  # 앱 진입점, 화면 이동, 앱 모델
    │   ├── DesignSystem         # 디자인 토큰과 UI 구성 요소
    │   ├── Model                # 설정, 요청, 수신 문서
    │   ├── Resources            # 에셋과 폰트
    │   ├── Screens              # 화면
    │   ├── Session              # 검증 세션 (SDK / mock)
    │   ├── Support              # 아이콘, 밀어서 뒤로 가기 제스처
    │   └── Trust                # 신뢰 발급자 목록, DID Document 키 조회
    └── Config                   # Info.plist 와 엔타이틀먼트 (NFC)
```

## 빌드 방법
Xcode 기본 빌드 시스템으로 앱을 컴파일하고 테스트하는 방법입니다.
1. Xcode 설치
    - Xcode 를 실행하고 상단 메뉴의 File > Open 에서 프로젝트 파일(.xcodeproj)을 엽니다.
2. 프로젝트 열기
    - 프로젝트를 열면 Xcode 창 왼쪽의 Project Navigator 에서 소스 파일, 리소스 파일, 설정 파일을 확인할 수 있습니다.
3. 시뮬레이터 또는 실기기 선택
    - Xcode 창 상단에서 빌드하고 실행할 대상 기기를 선택합니다.
- 시뮬레이터: 화면은 동작하지만 BLE, NFC, 카메라를 쓸 수 없습니다. 아래의 mock 세션을 사용합니다.
- 실기기: 홀더와 실제 검증을 하려면 실기기가 필요합니다.

4. 프로젝트 설정 확인
    - 왼쪽 프로젝트 트리에서 프로젝트 파일을 선택하고 Target 설정의 Signing & Capabilities 를 확인합니다. 실기기 빌드에는 Apple Developer 포털에서 App ID 에 **Near Field Communication Tag Reading** capability 를 켜 두어야 합니다.

명령줄에서 같은 빌드를 하려면:
```sh
xcodebuild -project source/ProximityVerifier.xcodeproj -scheme ProximityVerifier \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## SDK 적용 방법
앱은 SDK 를 Swift Package 로 사용합니다. 프로젝트에 `MdocReader` product 가 이미 등록되어 있어, 처음 열 때 Xcode 가 패키지를 내려받으며 클론 후 따로 할 일은 없습니다.

| 항목       | 값                                                       |
|------------|----------------------------------------------------------|
| 패키지     | `https://github.com/OmniOneID/did-proximity-sdk-ios.git` |
| 의존 규칙  | 정확한 버전 `1.0.0` (태그 `v1.0.0`)                      |
| Product    | `MdocReader` (`import MdocReader`)                       |

받아 온 리비전은 `source/ProximityVerifier.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` 에 고정됩니다. 새 SDK 릴리스로 올리려면 Xcode 의 **Project → Package Dependencies** 에서 버전을 바꿉니다.

SDK 자체의 라이선스와 의존성은 SDK 저장소를 참고해 주세요.
<br>
[mdoc Proximity SDK License-dependencies](https://github.com/OmniOneID/did-proximity-sdk-ios/blob/main/dependencies-license.md)

## 앱 설정

### NFC
NFC engagement 와 NFC 데이터 수신은 ISO 7816 태그용 `NFCTagReaderSession` 을 씁니다. 필요한 설정은 `source/Config/` 아래 두 파일에 있습니다.

| 파일 | 키 |
| --- | --- |
| `source/Config/ProximityVerifier.entitlements` | `com.apple.developer.nfc.readersession.formats` = `TAG` |
| `source/Config/Info.plist` | `com.apple.developer.nfc.readersession.iso7816.select-identifiers` |

AID 두 개를 모두, 다음 순서로 등록해야 합니다.
1. `D2760000850101` — NFC Forum Type 4 Tag (engagement). 시스템이 처음 응답한 AID 에서 멈추므로 반드시 앞에 둡니다.
2. `A0000002480400` — mdoc 데이터 수신. 없으면 데이터 수신용 SELECT 가 거부됩니다.

### 신뢰 발급자
신뢰 발급자 목록은 TAS 목록 API(`GET /list/api/v1/mdoc/issuers`)에서, 목록에 있는 발급자의 DID Document 는 API Gateway(`GET /api-gateway/api/v1/did-doc?did=...`)에서 가져옵니다. **Refresh Trusted Issuers** 를 누르면 둘을 함께 받아 단말에 저장하고, 검증은 저장된 사본만으로 합니다. 신뢰 발급자 목록이 비어 있으면 모든 발급자를 거부합니다.

두 서버 주소는 **Server URL** 화면(Settings → Trusted Issuers → 앱 바의 톱니바퀴 아이콘)에서 설정합니다. 서버마다 Default(빌드 기본값) 또는 Custom(화면에서 입력한 URL) 중 하나를 씁니다. 저장한 값은 재시작 없이 다음 요청부터 적용되며, 저장으로 실제 사용 URL 이 바뀌면 저장된 신뢰 발급자 목록을 지우므로 다시 갱신해야 합니다.

| 서버 | 제공 | 빌드 기본값 |
| --- | --- | --- |
| TAS | 신뢰 발급자 목록 | `http://192.168.3.110:8090` |
| API Gateway | 발급자 DID Document | `http://192.168.3.110:8093` |

빌드 기본값은 개발 LAN 서버(http)이며 `ServerEndpoint.defaultValue` (`source/ProximityVerifier/Trust/ServerURLStore.swift`)에 정의되어 있으므로 출시 전에 운영 주소로 바꿉니다. http 통신은 `source/Config/Info.plist` 의 `NSAllowsArbitraryLoads` 로 허용하며, 같은 파일에 로컬 네트워크 접근용 `NSLocalNetworkUsageDescription` 도 선언되어 있습니다.

### 홀더 없이 실행하기 (DEBUG 전용)
디버그 빌드는 SDK 세션을 샘플 데이터로 바꾸는 실행 인자를 받습니다.
```sh
xcrun simctl launch <device> org.omnione.did.proximity.verifier -mock
```

## 수정내역

수정내역은 아래에서 확인할 수 있습니다.
<br>
- [Proximity Verifier iOS](CHANGELOG.md)  

## 데모 영상 <br>
OpenDID 시스템의 실제 동작을 보여주는 데모 영상은 [Demo Repository](https://github.com/OmniOneID/did-demo-server)에서 확인하실 수 있습니다. <br>

사용자 등록, VC 발급, VP 제출 등 주요 기능들을 영상으로 확인하실 수 있습니다.

## 기여
Contributing 및 pull request 제출 절차에 대한 자세한 내용은 [CONTRIBUTING.md](CONTRIBUTING.md)와 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)를 참조해 주세요.

## 라이선스
[Apache 2.0](LICENSE)
