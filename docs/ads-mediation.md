# AdMob + Unity Ads 배너 비딩

기준일: 2026-10-04. 사용자는 PubMatic을 제외하고 AdMob에 Unity Ads만 추가하기로 했다. LevelPlay로 전환하지 않는다. Unity Ads iOS AdMob 어댑터는 배너·전면·보상형을 지원하며 네이티브는 지원하지 않는다. 이 앱의 적용 범위는 기존 배너 광고 단위다.

## 앱 연동

- 공식 SPM: `https://github.com/googleads/googleads-mobile-ios-mediation-unity.git`
- 정확한 SPM tag: `4.20.100`(adapter binary 4.20.1.0); transitive Unity Ads 4.20.1.
- Google Mobile Ads 직접 요구 버전을 13.9.0 이상, 14 미만으로 올린다. 실제 해석 버전은 Package.resolved를 따른다.
- 기존 anchored adaptive banner API는 v13에서 deprecated지만 유지하므로 이 작업에서 배너 크기/화면 디자인을 바꾸지 않는다.
- `BannerAdService`가 기존 UMP/Remote Config 승인 경로에서 Google SDK를 시작하기 전에 Unity privacy metadata와 adapter test mode를 설정한다. Unity를 따로 initialize하거나 광고를 직접 요청하지 않는다.
- 최초 도입은 Unity `privacy.consent=false`를 고정한다. UMP의 `canRequestAds=true`는 개인화 동의가 아니므로 이를 Unity 개인화 동의로 변환하지 않는다. 비개인화 설정은 Unity 수익 잠재력을 제한할 수 있다. 개인화는 지역별 동의 전달과 철회가 검증된 별도 변경에서만 허용한다.
- Debug는 Google 테스트 ID를 유지한다. Google 샘플 단위에서 Google 광고가 보이는 것은 Unity 비딩 검증이 아니다.
- Unity 공식 SKAdNetwork 목록을 Info.plist에 기존 Google ID와 중복 없이 병합했다. SKAdNetwork 등록은 해당 네트워크와 파트너십을 맺거나 SDK를 설치하는 작업이 아니다.

## 콘솔 완료 순서

1. Unity Ads에 로그인하고 앱 프로젝트를 만든다. Monetization에서 Mediation / Google AdMob / Bidding / iOS를 선택하고 실제 앱의 audience 설정을 확인한다. Game ID와 Banner Placement ID를 가져온다. 이름·사업자 유형·아동 대상 여부 등 사용자 고유 정보를 임의로 입력하지 않는다.
2. Unity가 제시한 계약을 사용자가 검토하고 동의한다. AdMob의 보안 신호 공유·광고 데이터 처리 약관 동의와 입찰 계약 확인도 실제 동의 화면에서 별도 승인 후 진행한다.
3. AdMob의 기존 일시중지 `TK8 iOS Banner Bidding` 그룹에 Unity Ads(Bidding)를 추가하고 실제 Game ID / Banner Placement ID를 매핑한다. Native 그룹에는 추가하지 않는다.
4. Unity Organization Settings의 실제 app-ads.txt 전체 목록을 기존 `app-ads.txt`에 병합하고 App Store에 등록된 개발자 웹사이트 루트에 게시한다. Unity seller ID를 Game ID나 임의 값으로 대체하지 않는다. 사용자 요청 없이 Git push/사이트 배포를 하지 않는다.
5. AdMob Privacy & messaging의 European / US regulations 광고 파트너 목록과 필요한 게시된 UMP 메시지에서 Unity를 확인한다. 앱의 비개인화 설정을 개인화 동의로 대신 간주하지 않는다.
6. 실제 AdMob 배너 단위를 사용하는 테스트 기기를 등록하고 Unity 테스트 모드를 적용한 다음 Ad Inspector single ad source testing(Unity Ads Bidding)으로 로드·노출과 adapter 응답을 확인한다. 운영 단위로 테스트하면서 실제 광고를 클릭하지 않는다. 전체 사용자에게 테스트 모드를 강제하지 않는다.
7. 앱의 Unity SDK 포함 버전을 배포한 뒤, 기존 버전의 요청 처리 범위를 고려해 그룹을 활성화한다. 테스트 기기 설정과 운영 설정을 확인하고 Google-only 대비 fill rate, 노출당 수익, 총수익, 로드 실패/지연을 비교한다. 수익 개선은 보장되지 않는다.

## 현재 상태와 검증 경계

### 저장한 배너 매핑

| 항목 | 값 |
| --- | --- |
| Unity 프로젝트 / 앱 | TK8 / iOS, App Store ID `6745224754`, bundle `com.moongoon.TK8` |
| Unity Game ID | `800387680` |
| Unity Banner Placement ID | `BP_Banner_iOS` |
| AdMob 매핑 이름 | `TK8 iOS Unity Banner Bidding` |
| 기존 AdMob Banner 단위 | `ca-app-pub-3866042653915701/3419960087` |
| 미디에이션 그룹 | `TK8 iOS Banner Bidding` (`2616972651`), 일시중지 |

- 사용자가 Unity 개인 정산 프로필 제출과 AdMob 약관 동의를 완료했다고 알려 줬다. 이후 Unity 앱 등록과 배너 광고 단위 생성, AdMob 매핑 및 그룹 저장을 완료했다. AdMob에서 Unity와 Google 소스는 모두 `준비됨`, 파트너십은 `활성`이다. 국가별 정산 최종 승인이나 실제 입금 완료를 뜻하지 않는다.
- Unity는 Google AdMob / Bidding / iOS로 등록했다. Rewarded와 Interstitial은 생성하지 않았고 선택적 Developer Data 공유도 켜지 않았다. 앱은 특정 아동 대상이 아닌 일반 대상 설정이다.
- 네이티브 그룹은 Google 기본 소스만 포함한 일시중지 상태다. PubMatic 직접 소스와 LevelPlay는 추가하지 않았다.
- Unity 개발자 웹사이트는 App Store의 실제 seller URL인 `https://moongoon72.github.io`로 저장했다. 실제 게시 경로는 `https://moongoon72.github.io/app-ads.txt`다.
- 저장소 루트 `app-ads.txt`에 기존 운영 Google DIRECT 항목과 Unity 콘솔의 전체 판매자 160건을 병합했다. ownerdomain 1줄과 중복 없는 판매자 161줄이다. Unity DIRECT seller ID는 `153987282`이며 Game ID와 다르다. Unity 목록의 PubMatic 등 RESELLER 항목은 Unity의 재판매 경로이며 직접 PubMatic 소스 추가가 아니다.
- 사용자가 개발자 웹사이트 app-ads.txt 게시를 완료했다고 후속 보고했다. 앞선 Google DIRECT 1줄만 게시된 상태는 게시 전 관측이다. 이번 공개 URL 조회는 네트워크/DNS 오류로 내용과 Unity 크롤링 완료를 재검증하지 못했다. 사용자 게시 완료와 Unity 크롤링 검증을 구분한다. 이 앱 저장소의 파일 수정만으로 웹사이트에 배포되지는 않는다.
- AdMob 유럽 규정 광고 파트너 목록에 `Unity Technologies SF`(GVL ID `1549`)가 이미 선택되어 있다. 미국 주 규정의 활동 중인 광고 파트너 목록에도 `Unity Ads`가 이미 선택되어 있다. 이 확인에서 파트너나 개인정보 설정을 변경하지 않았다.
- 이전 유럽 메시지 신규 생성 안내 상태 이후 `TK8 iOS European Consent` 초안을 저장했다. TK8 iOS만 선택, 영어 기본, EEA·영국·스위스 타겟팅, 동의/거절/선택 관리 버튼을 적용하고 사용자가 제공한 GitHub Wiki URL을 연결했다. 지원 언어 목록에 한국어가 없어 추가하지 않았다. 기존 정책의 「수집 안함」과 SDK 동작 불일치를 발견해 수정안을 준비했고, 사용자의 명시적 승인 후 Wiki와 이 메시지를 공개 게시했다. 콘솔 「게시됨」과 앱의 실제 메시지 표시를 확인했다. 기존 자동 생성/메시지 커버리지 확대 설정은 켜져 있으므로 이를 모든 동의 보호가 없다는 뜻으로 해석하지 않는다. 실제 서비스 대상 지역의 UMP 메시지 구성과 동작은 활성화 전에 확인해야 한다.
- SDK 포함 앱의 운영 배포, 실기기 Unity 테스트, 운영 송출·수익은 아직 미검증이다. 별도 단위의 시뮬레이터 Unity 단일 소스 로드·노출은 아래 후속 검증에서 성공했다. 배너 그룹은 이 검증과 배포가 끝날 때까지 일시중지로 유지했다.
- 앱 검증은 TK8Tests 133건과 SupabaseAPITests 1건 통과, 실제 기기 arm64 Release build(서명 제외) 성공이다. 이는 콘솔 매핑 전 앱 연동 검증이며 실제 Unity 광고 송출 검증과 구분한다. 결과 경로는 implementation-notes.md에 기록했다.

## 배포 전 검증 순서

1. AdMob 개인 정보 보호 및 메시지 → 유럽 규정 → 메시지 만들기에서 TK8 iOS를 선택한다. 실제 개인정보처리방침 URL, 앱 지원 언어, EEA·영국·스위스 타겟팅과 동의/거절/선택 관리 버튼을 확인하고 미리보기 후 게시한다. 기존 Unity 파트너 선택을 유지한다.
2. 일반 Debug는 Google 샘플 광고와 UMP 우회 경로라 Unity 검증에 사용하지 않는다. 실제 앱 AdMob App ID를 유지하고 별도의 AdMob 배너 광고 단위를 사용하는 검증용 빌드를 실기기 또는 TestFlight에 설치한다. 별도 단위를 Unity에 매핑한 테스트 그룹만 활성화하고 기존 운영 그룹은 일시중지를 유지한다. 검증 경로는 Debug 전용 shared scheme으로 구현했다. 아래 실행 절차를 따른다.
3. UMP 테스트 기기와 강제 EEA 지역 설정으로 동의/거절과 앱 설정의 개인정보 선택 변경을 확인한다. 강제 지역과 consent reset은 검증 빌드에만 적용한다.
4. AdMob 및 Unity에 해당 실기기를 테스트 기기로 등록하고 Unity 테스트 광고를 켠다. Ad Inspector의 단일 소스 테스트에서 Unity Ads를 선택하고 앱 재시작 후 배너 로드·노출과 응답을 확인한다. Google 샘플 배너가 표시된 것을 Unity 성공으로 계산하지 않는다.
5. 검증용 설정을 운영에서 제거하고 SDK 포함 버전을 App Store에 배포한다. 배포 상태와 기존 버전 요청을 고려한 뒤 운영 배너 그룹을 활성화한다. 테스트는 공개 App Store 배포 전에 완료한다.

## 공식 근거

- [Google iOS Unity Ads mediation](https://developers.google.com/admob/ios/mediation/unity)
- [Google v13 migration](https://developers.google.com/admob/ios/migration)
- [Unity consumer privacy API](https://docs.unity.com/en-us/grow/ads/privacy/ccpa-compliance)
- [Unity SKAdNetwork IDs](https://docs.unity.com/en-us/grow/ads/ios-sdk/ios14/configure-ad-network-ids)
- [Unity app-ads.txt](https://docs.unity.com/en-us/grow/ads/optimization/app-ads-txt)

## 검증 전용 설정 — 2026-10-04

- 테스트 배너: `Unity Banner Integration Test` / `ca-app-pub-3866042653915701/3545679052`.
- 테스트 그룹: `TK8 iOS Unity Banner Test` (`5051561136`), 사용중. 위 단위 한 개만 포함하며 Google·Unity 소스가 준비됨이다. 운영 그룹은 일시중지 상태다.
- 테스트 매핑: `TK8 iOS Unity Banner Test Mapping`, 기존 Game `800387680` / Placement `BP_Banner_iOS`.
- Xcode에서 `TK8 Unity Mediation Test`를 선택한다. 실제 App ID를 유지하며 Run 환경변수 `TK8_UNITY_TEST_BANNER_ID`에는 위 별도 단위를 사용한다. 일반 앱 scheme에는 검증 설정을 추가하지 않는다.
- 실기기 최초 등록은 일반 `Tekken8 Frame Data` Debug scheme으로 Google 샘플 광고를 먼저 요청하고 AdMob 로그의 테스트 기기 해시를 확인한다. 이 해시를 공유 검증 scheme에서 복제한 개인용 scheme의 `TK8_ADMOB_TEST_DEVICE_IDS`에 등록한 뒤 검증용 scheme으로 실행한다. UMP 로그에서 별도의 테스트 기기 해시를 확인하고 로컬 Run 설정의 `TK8_UMP_TEST_DEVICE_IDS`에도 입력해 두 환경변수를 활성화한다. 서로 같은 값이라고 가정하지 않는다. 공유 scheme에는 기기 식별자를 넣지 않는다. 개인용 scheme 생성 절차는 아래 실기기 안내를 따른다. Unity 콘솔 Testing에서도 해당 실기기를 등록하고 실제 override 설정을 확인한다.
- `-TK8UMPForceEEA`는 검증에서만 강제 지역을 사용한다. `-TK8UMPResetConsent`는 기본 꺼져 있고 새 선택 시나리오를 시작할 때만 일시적으로 켠다. 동의/거절/변경을 각각 확인할 때 초기화하며 실서비스에 사용하지 않는다.
- 앱 설정의 `Ad Inspector (test)` → Single ad source test → Unity Ads Bidding을 선택하고 재시작한다. 광고 요청 응답과 Unity 테스트 creative의 실제 노출이 함께 성공해야 완료다. 배너 fill이 AdMob Network이면 Unity 성공으로 계산하지 않는다.
- XcodeBuildMCP의 build_run_sim 실행은 scheme 환경변수 전달을 확인해야 한다. 이번에는 `launch_app_sim`의 명시적 env로 검증 모드를 실행했다.
- 첫 시뮬레이터 실행에서 Unity 초기화가 `-[GADMediationServerConfiguration gameIds]: unrecognized selector`로 실패했다. 어댑터 정적 archive에 해당 category가 있고 앱 binary에는 빠진 것을 nm로 확인해 앱 Debug/Release에 `$(inherited) -ObjC`를 추가했다. 버전 비호환으로 단정하거나 SDK 버전을 임의로 낮추지 않았다.
- 실제 개인정보처리방침 수정안은 `privacy-policy-update-draft.md`다. GA4 콘솔에서 이벤트 2개월, 사용자 14개월, 새 활동 시 사용자 보관기간 재설정 ON을 읽기 확인했다. 표준 집계 보고서 전체의 보관기간은 아니다. Firebase Analytics는 운영 빌드에서 UMP 광고 동의와 별개로 시작되며 이번 작업에서 수집 정책을 바꾸지 않았다.
- 게시되지 않은 메시지 상태의 실제 UMP 응답은 `no form(s) configured`였다. 테스트 광고 표시를 유럽 동의 흐름 성공으로 주장하지 않는다. 이 초기 응답 이후 사용자가 Wiki/메시지 게시를 승인했고 실제 게시 및 앱 수신을 확인했다. 실기기 로드/노출·서명/배포와 수익은 미완료다.

추가 근거: [Google iOS 설치와 -ObjC](https://developers.google.com/admob/ios/quick-start), [GA4 보관기간](https://support.google.com/analytics/answer/7667196?hl=ko).

### 실제 검증 결과

- 최종 TK8Tests 136건, SupabaseAPITests 1건 통과. `-ObjC` 반영 후 Simulator 앱 실행, 기기 arm64 Debug/Release build(서명 제외) 성공. 결과 `/private/tmp/tk8-unity-validation-final-tests.xcresult`, `/private/tmp/tk8-unity-validation-final-supabase.xcresult`, `/private/tmp/tk8-unity-validation-device-debug.log`, `/private/tmp/tk8-unity-validation-release.log`.
- 시뮬레이터 강제 EEA의 새 동의 메시지에서 거절 → 앱 복귀 → 설정의 개인정보 선택 → 동의 변경 → Manage options → Accept all → 다시 설정에서 거절(철회) → 앱 복귀를 확인했다. 광고 동의는 광고 선택이며 Analytics 동의 정책 변경 검증은 아니다.
- Ad Inspector에서 Unity adapter 4.20.1.0 초기화(713ms), SDK 4.20.1을 확인했다. `gameIds` 예외는 `-ObjC` 반영 후 사라졌다.
- Unity Ads(Bidding) 단일 소스 선택 후 앱 재시작 → 실제 Unity 테스트 배너 표시 → Ad Inspector의 테스트 단위 `Fill / Unity Ads` 응답을 확인했다. 검증 뒤 단일 소스 override를 종료했다. 증거 `/private/tmp/tk8-unity-test-banner.jpg`, `/private/tmp/tk8-unity-test-fill.jpg`, `/private/tmp/tk8-unity-adapter-initialized.jpg`.
- 공개 게시 증거 `/private/tmp/tk8-privacy-policy-published.jpg`, `/private/tmp/tk8-gdpr-published.jpg`. 테스트 그룹 증거 `/private/tmp/tk8-unity-test-group.jpg`, 메시지 앱 표시 증거 `/private/tmp/tk8-ump-consent-presented.jpg`.
- 운영 그룹 활성화는 하지 않았다. 실기기 확인과 실제 SDK 포함 버전 배포 뒤 진행한다. 이 결과를 실제 운영 입찰 경쟁·수익 증가·전체 법적 검토 완료로 확대하지 않는다.

- 실기기 발견 목록에서 iPhone의 연결 tunnel은 disconnected이고 DDI 서비스는 unavailable이었다. USB 연결 확인 전 실기기 설치나 테스트를 진행하지 않았다.


### 실기기에서 배너가 없고 광고 검사기 안내가 나올 때

- 미디에이션 검증은 일반 Debug 샘플 광고와 다르다. 실기기에서 `TK8_ADMOB_TEST_DEVICE_IDS`가 비어 있으면 앱이 배너 요청을 의도적으로 막는다. 시뮬레이터는 자동 테스트 기기라 같은 설정 누락이 드러나지 않는다.
- Xcode의 Product → Scheme → Manage Schemes에서 `TK8 Unity Mediation Test`를 Duplicate하고 이름을 `TK8 Unity Device Test (local)`로 지정한다. Shared를 끈다. 파일은 git-ignore된 `xcuserdata` 안에 있어야 한다.
- 개인용 scheme의 Edit Scheme → Run → Arguments → Environment Variables에서 SDK 로그의 UMP ID를 `TK8_UMP_TEST_DEVICE_IDS`, Google ID를 `TK8_ADMOB_TEST_DEVICE_IDS`에 각각 넣고 체크한다. SDK의 테스트 기기 ID를 사용하며 iPhone UDID 또는 광고 단위 ID를 대신 넣지 않는다. 서로 같은 값이라고 가정하지 않는다. 코드의 programmatic 등록을 사용하므로 이 경로에서는 별도 AdMob 콘솔 기기 등록을 중복할 필요가 없다.
- `-TK8UMPForceEEA`는 켜고, 새 동의 화면을 확인할 최초 실행에만 `-TK8UMPResetConsent`를 켠다. 선택을 완료한 뒤 reset을 끄고 다음 재시작에서는 동의 선택을 유지한다. 모든 동의 수락을 광고 검사기의 필수 조건으로 안내하지 않는다. UMP의 `canRequestAds`를 따른다.
- 앱을 종료/Run하여 로컬 환경변수를 적용한다. 동의 선택을 완료하고 앱 설정 → 광고 검사기(테스트)를 연다. 이 화면의 기존 안내 알림은 여러 오류를 같은 문구로 표시하므로 해당 알림만으로 동의 미완료를 확정하지 않는다. SDK 오류와 `[Ads validation]` 로그를 함께 확인한다.
- 광고 검사기의 Single ad source test → Unity Ads (Bidding)를 선택하고 Xcode에서 개인용 scheme으로 Stop → Run(⌘R)한다. 홈 화면 아이콘으로 실행하면 scheme의 검증 인자/환경변수가 적용되지 않으므로 이 검증에서는 Xcode에서 재실행한다. 별도 테스트 단위의 배너 표시와 요청 응답 `Fill / Unity Ads`를 함께 확인한 뒤 override를 종료한다.
- 2026-10-04 실기기 Xcode 로그에서 테스트 ID 미등록에 따른 배너 차단을 확인했다. 위 개인용 scheme에 두 ID를 로컬 등록하고 실제 iPhone에서 빌드/실행했다. Unity SDK 초기화 성공 및 `Ad inspector enabled` 로그를 확인했고, 사용자가 동의 화면 완료 후 검사기 열림을 확인했다. 실기기의 Unity 단일 소스 fill/노출은 아직 확인하지 않았으며 운영 배포나 운영 그룹 활성화로 확대 해석하지 않는다. 기기 ID는 이 문서에 기록하지 않는다.

근거: [Google 테스트 광고](https://developers.google.com/admob/ios/test-ads), [UMP 테스트 기기·강제 지역](https://developers.google.com/admob/ios/privacy#testing), [단일 광고 소스 테스트](https://developers.google.com/admob/ios/ad-inspector/test-ad-units#test_a_single_ad_source).
