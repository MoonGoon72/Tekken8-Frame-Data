# TK8 Architecture

이 문서는 현재 저장소의 코드와 Xcode 설정을 기준으로 TK8 앱의 기술 스택, 디렉터리 구성, 주요 모듈 책임, 데이터 흐름을 설명한다. 구조 변경 작업에서는 이 문서를 기준선으로 사용하고, 실제 구조가 달라지면 같은 작업에서 함께 갱신한다.

- 기준일: 2026-09-11
- 앱 타깃: `TK8` (`Tekken8 Frame Data` scheme)
- 최소 지원 버전: iOS 17.0
- 기본 구조: MVVM + Repository Pattern + 수동 Dependency Injection

## 전체 구조

```text
AppDelegate / SceneDelegate
          |
          v
     DIContainer
          |
          v
UIKit ViewController ------> SwiftUI Cell / Filter
          |
      Combine binding
          |
          v
       ViewModel
          |
    Repository Protocol
          |
          +-------------------+--------------------+
          |                   |                    |
          v                   v                    v
  Supabase/PostgREST      Core Data           UserDefaults
                          (cache + memo)      (version + preference)
```

`SceneDelegate`가 `DIContainer`를 소유하고 루트 화면을 조립한다. 화면 전환은 `UINavigationController`와 각 ViewController가 담당하며, ViewModel은 Repository protocol에 의존한다. Repository 구현체가 Supabase와 로컬 저장소를 선택하고 DTO를 통해 원격/영속 모델을 앱 도메인 모델로 변환한다.

## 기술 스택

| 구분 | 기술 및 용도 |
|---|---|
| 언어/플랫폼 | Swift 5, iOS 17.0+ |
| UI | UIKit 기반 화면과 navigation, SwiftUI 기반 셀·필터·작은 컴포넌트, `UIHostingConfiguration`/`UIHostingController` 브리지 |
| 상태/바인딩 | Combine의 `@Published`, `AnyPublisher`, `sink` |
| 비동기 | Swift Concurrency의 `async/await`, `Task`, `TaskGroup` |
| 아키텍처 | MVVM, Repository Pattern, protocol 기반 의존성 역전, `DIContainer` 수동 조립 |
| 원격 데이터 | Supabase Swift SDK, PostgREST (`character`, `move`, 버전 테이블) |
| 원격 파일 | `character.image_url`에 저장된 공개 캐릭터 이미지 URL (현재 Google Drive 호스팅) |
| 로컬 데이터 | Core Data (`CharacterEntity`, `MoveEntity`, `MemoEntity`) |
| 설정 저장 | UserDefaults 및 `UserDefaultsManageable` |
| 이미지 캐시 | `NSCache` + 앱 Caches 디렉터리 + `URLSession` |
| 다국어 | String Catalog(`Localizable.xcstrings`) + 프레임 데이터 규칙 기반 한/영 변환 |
| 분석 | Firebase Analytics + Firebase Remote Config |
| 광고 | Google Mobile Ads의 적응형 하단 배너와 기술표의 네이티브 카드. UMP가 광고 요청을 허용한 뒤 요청하고 Remote Config로 표시를 중단할 수 있음 |
| 테스트 | XCTest, in-memory Core Data, Supabase 경계 테스트 |
| 의존성 관리 | Swift Package Manager; 직접 의존성은 `supabase-swift`, `firebase-ios-sdk`, Google Mobile Ads package |
| CI | GitHub Actions에서 SPM resolve 후 iOS Simulator용 clean build, Xcode Cloud에서 `main` 변경 시 Archive 및 TestFlight 전달 |

패키지의 정확한 해상 버전은 `TK8.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`가 기준이다.

## 폴더 구조

```text
.
├── Tekken8 Frame Data/
│   ├── TK8/                         # 앱 타깃 소스(file-system synchronized group)
│   │   ├── App/                     # AppDelegate, SceneDelegate
│   │   ├── Character/               # 캐릭터 목록·검색·레이아웃·이미지 표시
│   │   ├── CharacterSelect/         # 메모 작성 중 캐릭터 선택
│   │   ├── Memo/                    # 메모 CRUD, 검색, pin, import/export
│   │   ├── Move/                    # 기술 목록, 검색/필터, 현지화, 커맨드 표시
│   │   ├── OnBoarding/              # 버전별 온보딩 표시
│   │   ├── Repository/
│   │   │   ├── Data/                # Repository protocol/구현체, DTO 매핑
│   │   │   ├── Network/             # Supabase adapter와 범용 URLSession 추상화
│   │   │   └── Persistant/          # Core Data/UserDefaults adapter (현재 폴더명 철자 유지)
│   │   ├── Settings/                # 버전 정보, 문의, 후원/외부 링크
│   │   ├── Utility/                 # DI, 공통 View, 캐시, Analytics, Ads, extension, 상수
│   │   ├── Version/                 # 앱 스키마·프레임 데이터 버전 비교와 캐시 무효화
│   │   ├── Assets.xcassets/         # 캐릭터·커맨드·색상·앱 아이콘 에셋
│   │   ├── Localizable.xcstrings     # UI 현지화 문자열
│   │   └── Tekken8FrameData.xcdatamodeld/
│   ├── TK8Tests/                    # 도메인/번역/필터/메모 단위 테스트
│   ├── SupabaseAPITests/            # Supabase adapter 경계 테스트
│   ├── ci_scripts/                  # Xcode Cloud build 전 설정 생성 스크립트
│   └── TK8.xcodeproj/               # 타깃, scheme, build setting, SPM 설정
├── scripts/                         # 프레임 데이터 CSV 변환·검증·Supabase import
│   └── data/moves/                  # 캐릭터별 원천 CSV와 manifest
├── docs/                            # 아키텍처와 데이터 운영 문서
└── .github/workflows/               # 빌드 CI와 Supabase wake-up 작업
```

`Tekken8 Frame Data/View/MainViewController.swift`는 `TK8` file-system synchronized group 밖에 있는 빈 초기 파일이며 현재 앱 타깃의 실행 흐름에는 참여하지 않는다. `Repository/Network`의 `DefaultNetworkService`도 범용 URLSession 구현으로 남아 있지만 현재 DI는 `SupabaseManager`를 직접 사용한다.

## 주요 모듈과 책임

| 모듈 | 주요 타입 | 책임 |
|---|---|---|
| App/DI | `AppDelegate`, `SceneDelegate`, `DIContainer` | Firebase 초기화·수집 정책, 창/루트 navigation 구성, manager·repository·view model·view controller·analytics·광고 서비스 조립 |
| Character | `CharacterListViewController`, `CharacterListViewModel` | 캐릭터 조회/검색/정렬, list/grid 전환, 이미지 로딩, 기술·메모·설정 화면 진입 |
| Move | `MoveListViewController`, `MoveListViewModel`, `TranslatorEngine` | 캐릭터별 기술 조회, 언어별 변환, 섹션 정렬, 키워드·속성·프레임 필터, diffable snapshot 구성 |
| Memo | `MemoListViewController`, `MemoComposeViewController`, `MemoViewModel` | 로컬 메모 CRUD, pin/검색, 캐릭터 연결, `.tk8memos` 백업 import/export |
| Repository/Data | `DefaultCharacterRepository`, `DefaultMoveRepository`, `DefaultMemoRepository` | 데이터 출처 선택, 캐시 우선 조회, 원격 결과 저장, Core Data entity와 domain model 매핑 |
| Repository/Network | `SupabaseManager` | `character`, `move`, `frame_data_version`, `tekken_version` 조회 |
| Repository/Persistant | `CoreDataManager`, `UserDefaultsManager`, `CharacterLayoutPreference` | Core Data context/save/fetch/delete, 버전·온보딩·목록 레이아웃 설정 보존 |
| Version | `VersionManager` | 로컬 데이터 스키마 및 서버 프레임 데이터 버전을 비교해 캐릭터/기술 캐시 무효화 |
| Utility | `ImageCacheManager`, `AnalyticsClient`, `SearchAnalyticsTracker`, `BannerAdService`, `BannerAdHost`, base view/controller, extensions | 이미지 메모리/디스크 캐시, Firebase 이벤트 어댑터, 수동 화면 추적, 검색 디바운스·중복 제거, Remote Config·UMP 기반 광고 허용 판정, 공통 UI 생명주기, command parsing·localization 보조 |
| Data tooling | `import_moves_to_supabase.py`, apply shell scripts | 캐릭터별 CSV 검증, `sort_order` 계산, `(character_name, move_key)` 기준 Supabase upsert |

## 저장 데이터의 소유권

| 데이터 | 원본/외부 저장소 | 로컬 저장소 | 갱신 기준 |
|---|---|---|---|
| 캐릭터 | Supabase `character` | Core Data `CharacterEntity` | 캐시가 비었을 때 fetch; 버전 무효화 후 재fetch |
| 기술 | Supabase `move` | Core Data `MoveEntity` | 캐릭터별 캐시가 비었을 때 fetch; `sort_order` 순서 유지 |
| 프레임 데이터 버전 | Supabase `frame_data_version` | UserDefaults `Version` | 앱 시작 시 서버 값이 더 크면 캐릭터/기술 캐시 삭제 |
| 철권 버전 문자열 | Supabase `tekken_version` | UserDefaults `TekkenVersion` | 프레임 데이터 버전이 오른 경우 함께 갱신 |
| 메모 | 기기 로컬 | Core Data `MemoEntity` | 사용자 CRUD 및 백업 import; 프레임 캐시 무효화 대상이 아님 |
| 캐릭터 목록 모드 | 사용자 선택 | UserDefaults `characterLayout` | list/grid 토글 시 갱신 |
| 온보딩 표시 버전 | 앱 상수 | UserDefaults `onboarding_shown_version` | 현재 온보딩 버전 최초 표시 후 기록 |
| 캐릭터 이미지 | Asset Catalog 우선, 없으면 `character.image_url`의 외부 URL | `NSCache` + Caches 디렉터리 | 메모리 → 디스크 → 네트워크 순서 |

Core Data의 `deleteAll()`은 `CharacterEntity`와 `MoveEntity`만 batch delete한다. `MemoEntity`는 의도적으로 남아 프레임 데이터 버전 변경이나 로컬 스키마 캐시 무효화 후에도 사용자 메모가 유지된다.

## 런타임 데이터 흐름

### 1. 앱 시작과 캐시 무효화

```text
AppDelegate -- Firebase configure
     |
SceneDelegate
     |-- VersionManager.invalidateCacheIfAppUpdated()
     |      `-- 로컬 데이터 스키마 버전이 낮으면 Character/Move 삭제
     |
     |-- VersionManager.checkFrameDataVersion()
     |      |-- Supabase frame_data_version 조회
     |      |-- 서버 버전이 높으면 tekken_version 조회
     |      `-- 두 버전 응답이 유효할 때만 Character/Move 삭제
     |          + UserDefaults 버전 갱신
     |          + tekken_version 저장
     |
     `-- DIContainer가 CharacterListViewController를 루트로 생성
```

빈 버전 응답은 `SupabaseVersionError`로 전달되며, `SceneDelegate`가 이를 기록하고 기존 캐시를 유지한다. 캐시 삭제 뒤 `.allDatabaseDeleted` notification이 발행된다. `CharacterListViewModel`이 이를 구독해 캐릭터를 다시 요청한다. 시작 직후 최초 fetch와 비동기 버전 확인이 겹칠 수 있지만, 최종적으로 notification이 재fetch를 유도한다.

`FirebaseAutomaticScreenReportingEnabled`를 끄고 UIKit 화면의 `viewDidAppear`와 SwiftUI 필터의 `onAppear`에서 `AnalyticsClient`를 통해 안정적인 영문 `screen_view`를 수동 기록한다. 운영 빌드는 Firebase 수집을 사용하고, Debug 빌드는 `-FIRAnalyticsDebugEnabled` 실행 인자가 있을 때만 수집한다. 일반 Debug 및 테스트 호스트에서는 Firebase 초기화를 건너뛰고 DI에서 NoOp 클라이언트를 사용한다. 초기 수집값은 Info.plist에서 NO이며 허용된 실행에서만 활성화한다. 온보딩 종료 콜백으로 아래 화면의 분석 문맥과 버튼 노출을 복원한다.

### 2. 광고 표시와 원격 중단

`DIContainer`는 하나의 `BannerAdService`를 만들고 캐릭터 목록·기술 목록·메모 목록·설정 ViewController에 `BannerAdHost`를 주입한다. Host는 기존 화면 view를 감싸 적응형 하단 배너만 배치하며, 광고가 실제로 로드되기 전·로드 실패·원격 중단 시에는 높이 0으로 접어 콘텐츠 영역을 남기지 않는다. 메모 작성 화면에는 Host를 주입하지 않는다. 검색 키보드가 보이거나 메모 목록이 편집 상태이면 Host가 광고를 즉시 제거하고, 화면 이탈·백그라운드·폭 변경 뒤 늦게 도착한 SDK 콜백도 무시한다. 기술표는 하단 배너 대신 `NativeMoveAdLoader`가 위치별로 독립된 네이티브 광고를 요청하고, 성공한 경우 네 번째 기술 카드 뒤부터 20개 간격으로 SDK 자산 카드를 넣는다. 화면 이탈 시 로더는 보유 광고·진행 중 요청·delegate를 비우고 snapshot에서 광고 카드를 제거한다. 필터 결과가 바뀌면 더 이상 필요한 위치가 아닌 광고와 로더도 정리한다. Debug는 Google 네이티브 테스트 ID를 사용하고, Release는 실제 App ID와 네이티브 광고 단위 ID가 모두 유효할 때만 같은 경로를 사용한다. 위치별 요청이 실패하면 해당 카드와 빈 공간을 모두 남기지 않는다.

`BannerAdService`는 Firebase Remote Config의 `admob_banner_enabled`가 `true`일 때만 UMP 동의 정보를 갱신하고, `canRequestAds`가 true가 된 뒤 Google Mobile Ads SDK를 시작한다. 설정 화면은 UMP가 요구할 때만 `광고 개인정보 설정` 항목을 표시한다. 앱이 foreground가 될 때 Remote Config를 다시 가져오고 real-time update를 구독한다. 응답 실패나 앱 ID·광고 단위 ID 미설정 시에는 광고를 끈 상태로 유지한다. Debug는 실제 App ID 설정 여부와 관계없이 Google 샘플 광고 단위를 사용하고 Remote Config·운영 UMP 설정과 독립적으로 테스트 광고를 요청한다. Release는 유효한 실제 ID가 제공되기 전에는 광고를 요청하지 않는다.

### 3. 분석 이벤트

화면·사용자 액션은 ViewController/SwiftUI 필터에서 `AnalyticsClient`에 타입화된 `TK8AnalyticsEvent`를 전달한다. Firebase SDK 호출과 파라미터 변환은 `Utility/Analytics/AnalyticsClient.swift`에만 둔다. 검색은 UI 갱신을 지연시키지 않고, 실제 결과 snapshot 반영 뒤 `SearchAnalyticsTracker`가 검색 시도별 로컬 UUID로 오래된 완료를 거르고 500ms 디바운스와 동일 조건 중복 제거를 적용한다. 기술 목록 표시 이벤트는 snapshot 완료와 화면 노출을 모두 확인한다. 메모 저장은 `MemoComposeViewController`가 MemoViewModel의 onPersisted 콜백으로 repository 쓰기 성공 직후 성공 이벤트를 기록하고, 빈 내용·변경 없음·repository 오류를 서로 다른 계약으로 보낸다. 저장은 실제 pop 완료 후 수행하며 목록 재조회 실패는 저장 실패로 집계하지 않는다. 상세 이벤트 목록과 지표 분모/분자는 `docs/analytics-measurement.md`를 기준으로 한다.

### 4. 캐릭터 목록

1. `CharacterListViewController`가 `fetchCharacters()`를 요청한다.
2. `DefaultCharacterRepository`가 Core Data의 `CharacterEntity`를 먼저 조회한다.
3. 캐시가 있으면 DTO를 `Character`로 바꾸어 반환한다.
4. 캐시가 없으면 `SupabaseManager.fetchCharacter()`가 `character` 테이블을 조회하고 Core Data에 저장한다.
5. ViewModel이 기기 언어 기준으로 정렬하고 `@Published` 상태를 갱신한다.
6. ViewController가 Combine 구독을 통해 diffable data source snapshot을 적용한다.

### 5. 기술 목록과 필터

1. 캐릭터 선택 시 `DIContainer`가 해당 캐릭터용 `MoveListViewController`와 `DefaultMoveRepository`를 만든다.
2. Repository가 캐릭터 이름으로 `MoveEntity`를 `sortOrder` 오름차순 조회한다.
3. 캐시가 비었으면 Supabase `move` 테이블을 `character_name`으로 필터하고 `sort_order` 순으로 가져와 Core Data에 저장한다.
4. `MoveListViewModel`이 `TranslatorEngine`으로 표시 언어에 맞는 `LocalizedMove`를 병렬 생성한다.
5. 키워드, 섹션, 속성, 발동/가드 프레임 조건을 적용하고 섹션 및 `sortOrder` 기준으로 정렬한다.
6. UIKit collection view가 SwiftUI `MoveCell`을 `UIHostingConfiguration`으로 렌더링한다.

### 6. 캐릭터 이미지

`CharacterListViewModel`은 먼저 Asset Catalog에서 캐릭터 영문 이름과 같은 이미지를 찾는다. 로컬 에셋이 없으면 `Character.imageURL`의 HTTP(S) URL을 `ImageCacheManager`에 요청한다. 캐시는 `NSCache`, Caches 디렉터리, 네트워크 순으로 조회된다. 이미지 URL의 호스팅 제공자는 `character` 데이터가 소유하므로 앱 코드는 Supabase Storage 경로를 조합하지 않는다.

### 7. 메모와 백업

메모는 원격 서버를 사용하지 않는다. `MemoViewModel`이 `DefaultMemoRepository`를 통해 `MemoEntity`를 직접 CRUD하며 최신 수정일 순으로 읽는다. export는 전체 메모를 앱 전용 JSON 문서(`.tk8memos`)로 인코딩하고, import는 UUID가 같은 메모 중 가져온 `updatedAt`이 더 최신인 항목만 갱신한다.

### 8. 프레임 데이터 운영 흐름

```text
scripts/data/moves/<character>.csv
              |
              v
import_moves_to_supabase.py (기본 dry-run/검증)
              |
              | --apply --confirm-schema-ready
              v
Supabase move upsert
  key: (character_name, move_key)
  sort_order: CSV 행 순서로 계산
              |
              v
frame_data_version 증가
              |
              v
앱 시작 시 버전 비교 -> Core Data Character/Move 캐시 삭제 -> 재fetch
```

세부 실행 절차와 안전장치는 `docs/move-import-runbook.md`를 따른다. `character` row와 이미지 asset/Storage 항목은 move CSV import가 자동 생성하지 않으므로 신규 캐릭터 추가 시 별도로 준비해야 한다.

## 테스트와 검증 경계

- `TK8Tests`: 모델 decoding/hash, command tokenization, 한/영 번역, 기술 필터, 메모 CRUD와 백업 merge, Analytics 이벤트 계약·검색 디바운스·저장 판정, 배너 광고 정책·실패·늦은 SDK 응답 처리를 검증한다.
- `SupabaseAPITests`: `Character.swift`, `Move.swift`, `SupabaseManageable.swift`, 버전 모델을 테스트 target의 파일 동기화 예외로 직접 포함하고 mock을 사용해 Supabase adapter 경계를 검증한다. 앱 모듈 import에 의존하지 않아 앱의 Firebase/기타 패키지 의존성이 경계 테스트에 전파되지 않는다.
- CI의 `swift.yml`은 SPM 의존성을 해석하고 `Tekken8 Frame Data` scheme을 Simulator 대상으로 clean build한다. 현재 workflow에는 테스트 실행 단계가 별도로 없다.
- Xcode Cloud release workflow는 `main` 변경 시 Archive한다. `ci_scripts/ci_post_clone.sh`가 `CI_PRIMARY_REPOSITORY_PATH`의 실제 checkout 위치를 기준으로 workflow의 secret 환경변수 `API_KEY`, `SUPABASE_URL`를 추적되지 않는 `TK8/Secrets.xcconfig`에 원자적으로 기록한 뒤 Archive가 진행된다. 둘 중 하나라도 누락되면 스크립트가 실패해 잘못된 설정의 배포를 막는다. 기존 설정 파일이 있어도 최종 권한은 `600`으로 강제한다. `API_KEY`는 `sb_publishable_` key 또는 `role=anon` legacy JWT만 허용하며, secret/service-role key는 사용하지 않는다. Firebase Analytics 초기화에 필요한 `TK8/GoogleService-Info.plist`는 `FIREBASE_GOOGLE_SERVICE_INFO_PLIST_BASE64` secret environment variable을 post-clone 단계에서 Base64 복원한다. 복원 파일은 plist 문법과 `BUNDLE_ID=com.moongoon.TK8`을 검증하고 권한 `600`으로 원자적으로 교체한다. 따라서 Firebase configuration은 Git에 추적하지 않는다.
- Core Data 관련 테스트는 in-memory persistent store를 사용한다.
- Analytics 콘솔의 실제 사용자 수·전환율·DebugView 수집 상태와 AdMob 수익·실제 재방문 지표는 로컬 테스트 범위에 포함하지 않는다. 앱 DebugView 점검 절차와 맞춤 정의 대상은 `docs/analytics-measurement.md`에 기록한다.

## 구조 변경 시 동기화 대상

다음 변경은 `AGENTS.md` 규칙에 따라 이 문서를 같은 작업에서 갱신해야 한다.

- 새 feature/module 추가, 폴더 이동, Xcode target 또는 scheme 변경
- ViewController/ViewModel/Repository 책임이나 의존 방향 변경
- `DIContainer`의 조립 방식 및 앱 시작/navigation 흐름 변경
- Supabase 테이블·Storage, Core Data model, UserDefaults key의 역할 변경
- 캐시 우선순위, 무효화 조건, notification 흐름 변경
- Analytics 모듈, 이벤트 계약, 수동 화면 추적 또는 Debug 수집 정책 변경
- 핵심 SPM 의존성, 최소 iOS 버전, UI 프레임워크 또는 테스트/CI 전략 변경
