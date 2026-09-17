# TK8 Firebase Analytics 1차 측정 명세

- 측정 계약 버전: `1`
- 적용 앱 버전: `2.1.0`부터
- 대상: Firebase Analytics가 초기화된 운영 빌드와 DebugView를 명시적으로 켠 개발 빌드
- 원칙: 이벤트는 사용자가 확인 가능한 화면 반영·탭·실제 저장 성공처럼 의미가 확정되는 지점에서만 기록한다.

## 수집 및 화면 추적 정책

Firebase의 자동 `screen_view` swizzling은 `Info.plist`의 `FirebaseAutomaticScreenReportingEnabled = NO`로 끈다. 앱의 주요 화면은 `viewDidAppear`에서 안정적인 영문 화면명으로 수동 기록한다. 따라서 자동 화면 이벤트와 수동 화면 이벤트를 함께 집계하지 않는다.

| 화면명 (`firebase_screen`) | 기록 지점 |
|---|---|
| `character_list` | `CharacterListViewController.viewDidAppear` |
| `move_list` | `MoveListViewController.viewDidAppear` |
| `memo_list` | `MemoListViewController.viewDidAppear` |
| `memo_compose` | `MemoComposeViewController.viewDidAppear` |
| `settings` | `SettingViewController.viewDidAppear` |
| `character_select` | `CharacterSelectViewController.viewDidAppear` |
| `move_filter` | `FilterView.onAppear` |
| `onboarding` | `OnboardingViewController.viewDidAppear` |

운영 빌드는 수집을 켠다. `DEBUG` 빌드는 기본적으로 수집을 끄고, 실행 인자 `-FIRAnalyticsDebugEnabled`가 있을 때만 수집한다. DebugView 검증은 이 인자를 붙인 빌드에서 수행하며, 일반 Debug 실행 이벤트가 운영 집계에 섞이지 않도록 한다. Debug는 Google 테스트 광고를 위해 Firebase를 초기화하지만 Analytics 수집은 계속 끈다. 테스트 호스트는 광고 요청과 Analytics 모두 하지 않는다. Info.plist의 초기 수집값은 NO이며, 허용된 실행에서만 활성화한다. 온보딩이 캐릭터 목록을 덮는 동안 메모 버튼 노출을 기록하지 않고, 닫힌 뒤 화면명과 노출을 복원한다.

## 이벤트 계약

모든 이벤트 이름과 매개변수는 `Utility/Analytics/AnalyticsClient.swift`의 타입화된 생성자로 관리한다. 검색어 원문, 메모 제목·본문, 파일 경로, 자유 형식 오류 메시지는 전송하지 않는다.

| 이벤트 | 발생 조건 | 매개변수 |
|---|---|---|
| `character_selected` | 캐릭터 셀을 실제로 선택하고 기술 목록 이동을 시작할 때 1회 | `character_id` |
| `memo_entry_impression` | 캐릭터 목록 화면의 메모 버튼이 보이는 화면 방문마다 1회 | 없음 |
| `memo_entry_tapped` | 메모 진입 버튼 탭 시 1회 | 없음 |
| `search_results` | 비어 있지 않은 검색 조건에 대응하는 snapshot 완료 후 500ms 동안 조건이 유지될 때 | `search_scope`, `query_length`, `result_count`, 기술 검색의 `character_id` |
| `move_list_displayed` | 해당 캐릭터의 비어 있지 않은 기술 목록이 snapshot 반영 완료와 화면 표시를 모두 확인했을 때 컨트롤러당 1회 | `character_id`, `move_count` |
| `move_list_load_failed` | 기술 목록 repository 요청이 실패한 뒤 | `character_id`, `failure_code=repository_error` |
| `filter_opened` | 기술 목록의 필터 화면을 열 때 | `character_id` |
| `filter_applied` | 필터 화면에서 활성 조건을 `Apply`로 확정할 때 | `character_id`, `active_filter_count`, `section_count`, `attribute_count`, `startup_range_active`, `guard_range_active`, `result_count` |
| `filter_reset` | 활성 조건이 있는 상태에서 사용자가 전체 `Reset`을 탭할 때 | `character_id`, `previous_active_filter_count` |
| `memo_compose_started` | 새 메모 작성 또는 기존 메모 편집 화면으로 실제 이동할 때 | memo_mode=`create`\|`edit` |
| `memo_save_succeeded` | 메모 create/update의 영속 저장 성공 직후 | memo_mode=`create`\|`edit` |
| `memo_save_failed` | 메모 create/update가 실패한 뒤 | `memo_mode`, `failure_code=repository_error` |
| `memo_save_skipped` | 빈 메모 또는 변경 없는 편집을 저장하지 않고 종료할 때 | `memo_mode`, reason=`empty_content`\|`no_changes` |
| `banner_ad_impression` | SDK가 화면에 표시된 배너의 impression을 실제 기록할 때 | `ad_placement`, `ad_format=banner` |
| `banner_ad_load_failed` | SDK가 현재 화면의 배너 요청 실패를 알릴 때 | `ad_placement`, `ad_error_code` |
| `native_ad_impression` | SDK가 기술표 네이티브 카드의 impression을 실제 기록할 때 | `ad_placement=move_list`, `ad_format=native` |
| `native_ad_load_failed` | SDK가 기술표 네이티브 카드 요청 실패를 알릴 때 | `ad_placement=move_list`, `ad_error_code` |

`character_id`는 사용자 입력이 아닌 Supabase 캐릭터의 영문 이름을 소문자로 정규화한 안정 식별자다. `search_scope` 값은 `character_list`, `move_list`, `memo_list` 중 하나다.

`ad_placement`는 `character_list`, `move_list`, `memo_list`, `settings` 중 하나다. 광고 이벤트에는 광고 내용, 클릭 대상, 사용자 식별자, SDK 오류 문구를 전송하지 않는다. impression 이벤트는 SDK의 실제 callback에서만 기록하므로 화면 진입이나 광고 요청 수로 대체하지 않는다.

## 중복 제거 및 경계

### 검색

- UI 필터링은 지연하지 않는다. 검색 callback은 즉시 ViewModel을 갱신하고, Analytics만 500ms 디바운스한다.
- 검색어는 양끝 공백 제거 후 `String.count` 길이만 기록한다. 빈 검색어는 기록하지 않는다.
- snapshot 완료에서 타이머를 시작한다. 로컬 검색 시도 UUID로 오래된 snapshot 완료와 화면 이탈 후 완료를 무시한다. UUID와 검색 원문은 서버에 전송하지 않는다. 초기 로딩의 빈 목록은 검색 결과로 기록하지 않는다.
- 같은 화면 방문 중 같은 조건의 연속 callback은 1회로 합친다.
- 다른 조건으로 바꾼 뒤 이전 조건으로 돌아오면 별도의 유효한 검색 시도로 기록한다.
- 화면 이탈·검색 취소·빈 검색어 입력 시 예약 이벤트를 취소한다.
- 필터 열기/적용/초기화는 검색 이벤트를 발생시키지 않는다.

### 기술 목록

`move_list_displayed`는 요청 시작이나 navigation 시작이 아니라 비어 있지 않은 기술 snapshot 반영 완료와 실제 화면 표시를 모두 충족한 상태를 의미한다. 화면 이탈 후 완료된 데이터는 돌아와 보게 될 때까지 표시 이벤트를 보내지 않는다. 검색·필터로 snapshot이 다시 그려져도 성공 이벤트를 반복하지 않는다. 실패는 `repository_error`라는 제한된 코드만 사용한다.

### 필터

현재 UI는 상태를 편집한 뒤 `Apply` 버튼으로 확정한다. 활성 조건이 0개인 Apply 탭은 조건 적용으로 보지 않아 `filter_applied`를 기록하지 않는다. 전체 Reset은 편집 중인 활성 조건이 있을 때만 기록한다. `filter_reset`은 초안 초기화 탭이며, Apply 없이 닫으면 실제 필터 초기화를 뜻하지 않는다. `filter_applied.result_count`는 확정한 조건으로 계산된 기술 수이며 화면을 읽었다는 뜻은 아니다. 섹션·속성 블록의 내부 Clear와 초기 화면 상태는 사용자 전체 초기화 이벤트로 세지 않는다.

### 메모

작성 시작은 새 메모 진입과 기존 메모 편집 진입을 `memo_mode`로 구분한다. 저장 성공은 실제 repository 쓰기가 끝난 뒤 기록한다. 이후 목록 fetch가 실패해도 저장 실패로 중복 기록하지 않는다. 완료 버튼 탭 자체는 성공이 아니다. 빈 메모와 변경 없는 편집은 각각 `memo_save_skipped`로 구분한다. 저장 시도 오류율의 분모에서는 제외하지만, 메모 생성 CVR에서는 작성 시작 세션을 분모에 유지한다. 뒤로 가기가 실제 완료된 viewDidDisappear에서 저장하므로 취소된 interactive pop은 저장하지 않는다. 동일한 dismiss 저장은 1회 처리한다.

## 지표 정의

세션 퍼널은 GA4 사용자/세션 및 이벤트 순서를 사용해 계산한다. 전체 이벤트 횟수를 단순히 나누지 않는다.

| 지표 | 분모 | 분자 |
|---|---|---|
| 메모 진입 CTR | 같은 세션에서 `memo_entry_impression`이 발생한 세션 | 노출 이후 같은 세션에서 `memo_entry_tapped`가 발생한 세션 |
| 필터 사용 전환율 | `filter_opened`가 발생한 세션 | 그 이후 활성 조건이 있는 `filter_applied`가 발생한 세션 |
| 메모 생성 CVR | `memo_compose_started`의 `memo_mode=create`가 발생한 세션 | 그 이후 `memo_save_succeeded`의 `memo_mode=create`가 발생한 세션 |
| 기술 목록 도달률 | `character_selected`가 발생한 세션 | 그 이후 같은 `character_id`의 `move_list_displayed`가 발생한 세션 |
| 검색 결과 없음 비율 | 유효한 `search_results` 시도 | `result_count=0`인 시도 |

기술 목록 표시와 검색 결과는 사용자가 원하는 정보를 찾았다는 확정적 성공 신호가 아니므로 지표명을 `조회 성공`처럼 확대 해석하지 않는다.

## GA4/Firebase 맞춤 정의 등록 대상

Firebase Console의 Analytics > Custom Definitions에서 실제 보고서에 사용할 항목만 등록한다. `screen_view`의 Firebase 기본 화면 매개변수는 별도 등록 대상이 아니다.

- 맞춤 측정기준: `search_scope`, `character_id`, `memo_mode`, `failure_code`, `reason`, `ad_placement`, `ad_format`
- 맞춤 측정항목: `query_length`, `result_count`, `move_count`, `active_filter_count`, `section_count`, `attribute_count`, `previous_active_filter_count`, `ad_error_code`
- `startup_range_active`, `guard_range_active`는 SDK에 정수 0/1로 전송하며 보고서에서 비교하려면 이벤트 범위 맞춤 측정기준으로 등록한다.

등록 전후에 이벤트 이름·매개변수 철자와 범위를 이 문서 및 코드의 생성자와 함께 검토한다. BigQuery export와 대시보드는 1차 계측에 포함하지 않으며, 실제 데이터가 누적된 뒤 후속 작업으로 구성한다.

## 기존 이벤트 대응

| 이전 이벤트 | 1차 계측 이후 |
|---|---|
| `search_character` (`keyword` 원문) | `search_results` + `search_scope=character_list` |
| `search_move` (`keyword` 원문) | `search_results` + `search_scope=move_list` |
| `Character_selected` (`name`) | `character_selected` + `character_id` |

구 이벤트와 신 이벤트를 동시에 발행하지 않는다. 이벤트 이름은 Firebase에서 대소문자를 구분하므로 `Character_selected`와 `character_selected`를 하나의 이벤트로 취급하지 않는다.

## DebugView 점검 절차

1. Debug Scheme의 Run > Arguments Passed On Launch에 `-FIRAnalyticsDebugEnabled`를 추가한다.
2. 앱을 실행하고 캐릭터 선택, 기술 목록 표시, 검색, 필터 Apply/Reset, 메모 생성/편집 저장을 각각 수행한다.
3. Firebase Console > Analytics > DebugView에서 화면명과 이벤트 매개변수를 확인한다. 검색어 원문·메모 내용이 보이면 즉시 계측 계약 위반으로 수정한다.
4. 빠른 검색 입력, 검색 취소, 화면 재진입에서 중복 이벤트가 계약대로 줄어드는지 확인한다.
5. 확인 후 일반 Debug 실행에서는 해당 인자를 제거한다. 운영 데이터의 집계 검증은 배포 후 Analytics Events 보고서에서 별도로 한다.

## 광고 실험 운영

1. AdMob에 iOS 앱을 등록하고 실제 앱 ID와 banner/native ad unit ID를 Release build setting `ADMOB_APP_ID`, `ADMOB_BANNER_AD_UNIT_ID`, `ADMOB_NATIVE_AD_UNIT_ID`에 설정한다. 현재 두 광고 단위 ID는 설정돼 있고 앱 ID가 아직 없으므로, 값을 비워 두거나 Google 샘플 ID를 쓰는 동안 Release는 광고를 요청하지 않는다.
2. AdMob Privacy & messaging에서 필요한 UMP 메시지를 게시하고, Firebase Remote Config에 boolean `admob_banner_enabled`를 만든다. 배포 전 기본값은 `false`로 둔다.
3. Debug에서 Google 테스트 배너가 캐릭터·메모·설정 목록에만 보이고, 기술표에는 네 번째 기술 뒤부터 20개 간격의 네이티브 테스트 카드가 보이는지 확인한다. 위치별 광고 요청이 실패하면 해당 카드의 공간이 사라져야 한다. Release 기술표는 실제 App ID와 네이티브 광고 단위 ID가 유효할 때 같은 네이티브 카드 경로를 사용한다. Debug는 실제 App ID가 설정돼 있어도 Google 샘플 광고 단위를 사용하며 Remote Config와 운영 UMP 설정을 거치지 않는다.
4. 직접 사용해도 괜찮은 경우에만 Remote Config 값을 `true`로 변경해 배포된 앱에서 광고를 시작한다. 문제가 있으면 값을 `false`로 바꾼다. 앱은 foreground 재진입 또는 real-time config update 이후 광고와 공간을 제거한다.
5. 배포 전후로 같은 앱 버전 범위를 비교해 `banner_ad_impression`과 화면 방문·기술 목록 도달률을 보조 신호로 확인한다. 재방문 감소는 GA4의 retention 보고서에서 별도로 확인하며, 광고 이벤트만으로 광고가 원인이라고 단정하지 않는다.

공식 참고: [Firebase 이벤트 기록](https://firebase.google.com/docs/analytics/ios/events), [화면 추적](https://firebase.google.com/docs/analytics/screenviews), [DebugView](https://firebase.google.com/docs/analytics/debugview), [GA4 퍼널 탐색](https://support.google.com/analytics/answer/9327974)
