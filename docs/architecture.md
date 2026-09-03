# TK8 Architecture

이 문서는 현재 저장소의 코드와 Xcode 설정을 기준으로 TK8 앱의 기술 스택, 디렉터리 구성, 주요 모듈 책임, 데이터 흐름을 설명한다. 구조 변경 작업에서는 이 문서를 기준선으로 사용하고, 실제 구조가 달라지면 같은 작업에서 함께 갱신한다.

- 기준일: 2026-07-16
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
| 분석 | Firebase Analytics |
| 광고 의존성 | Google Mobile Ads가 앱 타깃에 링크되어 있으나 현재 `TK8` Swift 소스에서 직접 import하거나 호출하지 않음 |
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
│   │   ├── Utility/                 # DI, 공통 View, 캐시, extension, 상수
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
| App/DI | `AppDelegate`, `SceneDelegate`, `DIContainer` | Firebase 초기화, 창/루트 navigation 구성, manager·repository·view model·view controller 조립 |
| Character | `CharacterListViewController`, `CharacterListViewModel` | 캐릭터 조회/검색/정렬, list/grid 전환, 이미지 로딩, 기술·메모·설정 화면 진입 |
| Move | `MoveListViewController`, `MoveListViewModel`, `TranslatorEngine` | 캐릭터별 기술 조회, 언어별 변환, 섹션 정렬, 키워드·속성·프레임 필터, diffable snapshot 구성 |
| Memo | `MemoListViewController`, `MemoComposeViewController`, `MemoViewModel` | 로컬 메모 CRUD, pin/검색, 캐릭터 연결, `.tk8memos` 백업 import/export |
| Repository/Data | `DefaultCharacterRepository`, `DefaultMoveRepository`, `DefaultMemoRepository` | 데이터 출처 선택, 캐시 우선 조회, 원격 결과 저장, Core Data entity와 domain model 매핑 |
| Repository/Network | `SupabaseManager` | `character`, `move`, `frame_data_version`, `tekken_version` 조회 |
| Repository/Persistant | `CoreDataManager`, `UserDefaultsManager`, `CharacterLayoutPreference` | Core Data context/save/fetch/delete, 버전·온보딩·목록 레이아웃 설정 보존 |
| Version | `VersionManager` | 로컬 데이터 스키마 및 서버 프레임 데이터 버전을 비교해 캐릭터/기술 캐시 무효화 |
| Utility | `ImageCacheManager`, base view/controller, extensions | 이미지 메모리/디스크 캐시, 공통 UI 생명주기, command parsing·localization 보조 |
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

### 2. 캐릭터 목록

1. `CharacterListViewController`가 `fetchCharacters()`를 요청한다.
2. `DefaultCharacterRepository`가 Core Data의 `CharacterEntity`를 먼저 조회한다.
3. 캐시가 있으면 DTO를 `Character`로 바꾸어 반환한다.
4. 캐시가 없으면 `SupabaseManager.fetchCharacter()`가 `character` 테이블을 조회하고 Core Data에 저장한다.
5. ViewModel이 기기 언어 기준으로 정렬하고 `@Published` 상태를 갱신한다.
6. ViewController가 Combine 구독을 통해 diffable data source snapshot을 적용한다.

### 3. 기술 목록과 필터

1. 캐릭터 선택 시 `DIContainer`가 해당 캐릭터용 `MoveListViewController`와 `DefaultMoveRepository`를 만든다.
2. Repository가 캐릭터 이름으로 `MoveEntity`를 `sortOrder` 오름차순 조회한다.
3. 캐시가 비었으면 Supabase `move` 테이블을 `character_name`으로 필터하고 `sort_order` 순으로 가져와 Core Data에 저장한다.
4. `MoveListViewModel`이 `TranslatorEngine`으로 표시 언어에 맞는 `LocalizedMove`를 병렬 생성한다.
5. 키워드, 섹션, 속성, 발동/가드 프레임 조건을 적용하고 섹션 및 `sortOrder` 기준으로 정렬한다.
6. UIKit collection view가 SwiftUI `MoveCell`을 `UIHostingConfiguration`으로 렌더링한다.

### 4. 캐릭터 이미지

`CharacterListViewModel`은 먼저 Asset Catalog에서 캐릭터 영문 이름과 같은 이미지를 찾는다. 로컬 에셋이 없으면 `Character.imageURL`의 HTTP(S) URL을 `ImageCacheManager`에 요청한다. 캐시는 `NSCache`, Caches 디렉터리, 네트워크 순으로 조회된다. 이미지 URL의 호스팅 제공자는 `character` 데이터가 소유하므로 앱 코드는 Supabase Storage 경로를 조합하지 않는다.

### 5. 메모와 백업

메모는 원격 서버를 사용하지 않는다. `MemoViewModel`이 `DefaultMemoRepository`를 통해 `MemoEntity`를 직접 CRUD하며 최신 수정일 순으로 읽는다. export는 전체 메모를 앱 전용 JSON 문서(`.tk8memos`)로 인코딩하고, import는 UUID가 같은 메모 중 가져온 `updatedAt`이 더 최신인 항목만 갱신한다.

### 6. 프레임 데이터 운영 흐름

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

- `TK8Tests`: 모델 decoding/hash, command tokenization, 한/영 번역, 기술 필터, 메모 CRUD와 백업 merge를 검증한다.
- `SupabaseAPITests`: mock을 사용해 Supabase adapter 경계를 검증한다.
- CI의 `swift.yml`은 SPM 의존성을 해석하고 `Tekken8 Frame Data` scheme을 Simulator 대상으로 clean build한다. 현재 workflow에는 테스트 실행 단계가 별도로 없다.
- Xcode Cloud release workflow는 `main` 변경 시 Archive한다. `ci_scripts/ci_post_clone.sh`가 workflow의 secret 환경변수 `API_KEY`, `SUPABASE_URL`로 추적되지 않는 `TK8/Secrets.xcconfig`를 생성한 뒤 Archive가 진행된다. 세 값 중 하나라도 누락되면 스크립트가 실패해 잘못된 설정의 배포를 막는다. `API_KEY`는 클라이언트에 포함되는 Supabase anon key만 허용하며 service-role key는 사용하지 않는다.
- Core Data 관련 테스트는 in-memory persistent store를 사용한다.

## 구조 변경 시 동기화 대상

다음 변경은 `AGENTS.md` 규칙에 따라 이 문서를 같은 작업에서 갱신해야 한다.

- 새 feature/module 추가, 폴더 이동, Xcode target 또는 scheme 변경
- ViewController/ViewModel/Repository 책임이나 의존 방향 변경
- `DIContainer`의 조립 방식 및 앱 시작/navigation 흐름 변경
- Supabase 테이블·Storage, Core Data model, UserDefaults key의 역할 변경
- 캐시 우선순위, 무효화 조건, notification 흐름 변경
- 핵심 SPM 의존성, 최소 iOS 버전, UI 프레임워크 또는 테스트/CI 전략 변경
