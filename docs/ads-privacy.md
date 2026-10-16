# 광고 개인정보와 ATT

## 요청 흐름

- 광고 제거 구매가 없고 광고 표시 조건이 충족되면 첫 광고 준비에서 요청한다. 캐릭터 목록의 온보딩이 닫힌 뒤 진행한다.
- 운영/미디에이션 검증: UMP 갱신 및 필요한 동의 화면 → 앱 활성 상태에서 ATT 미결정 요청 → UMP 광고 요청 허용 확인 → Google SDK 시작 → 광고 요청.
- 일반 Debug는 Google 샘플 광고와 기존 UMP 우회를 유지하되 ATT 미결정 요청은 실행한다. XCTest 호스트는 광고·권한 요청을 실행하지 않는다.
- ATT 허용·거부·제한 상태에서는 다시 요청하지 않는다. 기존 설치 사용자도 미결정이면 요청 대상이다. 재설치 여부를 별도로 추정하지 않으며 iOS 권한 상태만 따른다.
- 시스템에서 추적 요청을 차단한 기기는 ATT 팝업이 표시되지 않을 수 있다. 설정 복귀 때 권한 상태를 재확인한다.
- ATT 허용: 기본 Google 광고 요청. UMP 선택/지역별 요건에 따라 SDK가 개인화 가능 여부를 판단한다. 개인화 광고 제공을 보장하지 않는다.
- ATT 거부/제한: 모든 Google 광고 placement에서 `npa=1` 요청. 앱 기능은 계속 사용할 수 있다.
- Unity 배너는 ATT 허용 여부와 별개로 기존 `privacy.consent=false`를 유지한다. Unity 지역 동의를 ATT나 UMP `canRequestAds`로 추정하지 않는다.
- 시스템 팝업 목적 설명은 `InfoPlist.xcstrings`의 영어/한국어를 사용한다. 일반 UI 문자열 카탈로그 `Localizable.xcstrings`에는 시스템 plist 키를 중복 추가하지 않는다.

## AdMob / App Store Connect 배포 확인

1. AdMob → 개인 정보 보호 및 메시지에서 해당 앱의 유럽 규정 메시지, 게시 상태, 대상 지역, 광고 파트너를 확인한다. 앱이 직접 ATT를 요청하므로 별도 IDFA 설명 메시지의 중복 설명 화면이 필요한지도 확인한다. GDPR 화면은 ATT와 별개로 유지한다.
2. 광고 개인화가 AdMob 계정/광고 단위의 다른 설정으로 차단돼 있지 않은지 확인한다. 앱 코드는 허용 시 비개인화 강제를 하지 않지만 계정 설정을 변경하지 않는다.
3. App Store Connect 앱 개인정보와 개인정보 처리방침을 실제 SDK 데이터 수집 및 추적 동작에 맞춰 확인한다. ATT 추가만으로 공개 항목이 자동 변경되지 않는다.
4. Review Notes에 첫 광고 준비/온보딩 종료 후 요청된다는 위치와 지역별 UMP 표시 차이를 적는다. Remote Config 광고 플래그가 켜지고 실제 광고 ID가 설정된 빌드로 심사 경로를 확인한다.

Review Notes 초안:

> After completing onboarding on the character list screen, the app requests App Tracking Transparency authorization before initializing the advertising SDK when the system authorization status is not determined. Users who have already allowed or denied the request are not prompted again. If tracking is denied or restricted, the app requests non-personalized Google ads and all app features remain available. The UMP European regulations message is shown separately when required by the configured region and consent status.

## 검증 시나리오

- 미결정: 온보딩 종료 → UMP(필요 지역) → ATT 1회 → 허용 또는 거부 후 광고 준비. 모달이 겹치지 않아야 한다.
- 허용/거부 후 재실행 및 화면 이동: ATT 재표시 없음.
- 기존 설치의 미결정 상태: 첫 광고 준비 시 요청.
- 설정에서 추적 요청 전체 차단/제한: 재요청 없이 비개인화 요청.
- 설정에서 허용을 거부로 변경 후 복귀: 기존 광고 폐기 후 비개인화 요청.
- 광고 제거 구매 또는 Remote Config OFF: 광고 준비 및 ATT 요청 없음.
- UMP 개인화 거부 + ATT 허용: UMP 선택을 존중. ATT로 강제 개인화하지 않음.
- 실기기에서 한국어/영어 목적 설명 및 심사 기기 크기 확인. Simulator 상태 테스트가 실제 광고 응답·수익·계정 설정의 검증을 대신하지 않는다.
