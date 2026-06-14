# TK8 (Tekken 8 Frame Data)

<img src="https://i.imgur.com/CtWdxoM.png" alt="TK8 banner" />

TK8은 철권 8 캐릭터별 기술 프레임 데이터를 빠르게 조회하고, 캐릭터별 메모를 함께 관리할 수 있는 iOS 앱입니다. 캐릭터 선택, 기술 검색, 섹션/속성/프레임 필터링, 한국어/영어 표시 전환, 오프라인 캐싱을 중심으로 구성되어 있습니다.

<img src="https://i.imgur.com/KmuJszr.png" alt="TK8 preview" />

## 프로젝트 상태

| 항목 | 내용 |
|---|---|
| App | TK8 |
| Platform | iOS 17.0+ |
| Language | Swift 5 |
| UI | UIKit + SwiftUI |
| Data | Supabase + Core Data |
| Tests | XCTest |

## 주요 기능

### 캐릭터 탐색

- 캐릭터 목록을 한국어/영어 이름 기준으로 검색합니다.
- 기기 언어 설정에 맞춰 캐릭터명을 정렬하고 표시합니다.
- 로컬 캐릭터 이미지 에셋을 우선 사용하고, 필요한 경우 Supabase Storage 이미지를 메모리/디스크 캐시에 저장합니다.

### 기술 프레임 데이터

- 캐릭터별 기술명, 커맨드, 판정, 데미지, 발동/가드/히트/카운터 프레임을 제공합니다.
- 기술명, 커맨드, 설명, 영어식 커맨드 표기까지 포함해 실시간 검색합니다.
- 커맨드와 판정은 텍스트만 나열하지 않고 아이콘/배지 기반으로 렌더링합니다.
- Diffable Data Source로 섹션별 기술 목록을 안정적으로 갱신합니다.

### 고급 필터

- 섹션 칩으로 `Heat`, `Rage`, `General`, 캐릭터 고유 섹션 등을 필터링합니다.
- 속성 아이콘으로 `heatburst`, `homing`, `powercrush`, `tornado`, `wall_break`, `floor_break` 등을 필터링합니다.
- 발동 프레임과 가드 프레임은 Range Slider와 프리셋으로 좁힐 수 있습니다.
- 필터 조건은 조건 간 AND, 같은 조건 안에서는 OR 방식으로 동작합니다.

### 메모

- 캐릭터별 메모를 작성, 수정, 삭제할 수 있습니다.
- 메모 작성 화면에서 캐릭터를 선택하고, 비어 있지 않은 메모는 화면을 벗어날 때 자동 저장합니다.
- 메모 검색, 고정/해제, 고정 섹션 표시, 다중 선택 삭제를 지원합니다.
- 메모 셀을 길게 누르면 미리보기와 함께 고정/삭제 메뉴가 표시됩니다.

### 다국어와 번역

- `Localizable.xcstrings` 기반으로 한국어/영어 UI를 제공합니다.
- 앱 표시 언어는 기기 선호 언어를 따릅니다.
- 한국어 원천 프레임 데이터는 영어 환경에서 규칙 기반 번역 엔진을 통해 표시됩니다.
- 커맨드 토큰은 보존하면서 설명만 번역하고, 검색 보조용 영어식 커맨드 표기도 생성합니다.

### 온보딩, 설정, 분석

- 버전별 온보딩으로 주요 기능 변경 사항을 안내합니다.
- 설정 화면에서 앱 버전, 철권 데이터 버전, 문의 메일, 후원 링크를 제공합니다.
- Firebase Analytics로 캐릭터 선택, 기술 검색, 후원 선택 등의 이벤트를 기록합니다.

## 아키텍처

MVVM + Repository Pattern을 기본으로, UIKit 화면에 SwiftUI 셀과 필터 화면을 함께 사용하는 구조입니다.

```text
SceneDelegate
    |
DIContainer
    |
ViewController (UIKit)
    |-- SwiftUI Cell / FilterView
    |
ViewModel (@MainActor, Combine)
    |
Repository Protocol
    |
Data Sources
    |-- Supabase / PostgREST
    |-- Core Data / UserDefaults
```

### 데이터 흐름

- 앱 시작 시 `VersionManager`가 로컬 스키마 버전과 서버 프레임 데이터 버전을 확인합니다.
- 캐시가 유효하면 Core Data를 먼저 사용하고, 비어 있거나 버전이 낮으면 Supabase에서 다시 가져옵니다.
- 캐시 무효화가 발생하면 Notification을 통해 캐릭터 목록을 다시 패치합니다.
- 네트워크, Core Data, UserDefaults 접근은 프로토콜 뒤에 두고 ViewModel은 구현체를 직접 알지 않게 구성했습니다.

## 기술 스택

| 분류 | 사용 기술 |
|---|---|
| Language | Swift 5 |
| UI | UIKit, SwiftUI, UIHostingConfiguration |
| State | Combine, `@Published` |
| Async | Swift Concurrency (`async/await`, `TaskGroup`) |
| Local DB | Core Data |
| Remote DB | Supabase, PostgREST |
| Storage | Supabase Storage |
| Analytics | Firebase Analytics |
| Test | XCTest, In-memory Core Data |

## 폴더 구조

```text
Tekken8 Frame Data/
├── TK8/
│   ├── App/                  # AppDelegate, SceneDelegate
│   ├── Character/            # 캐릭터 목록, 검색, 이미지 로딩
│   ├── CharacterSelect/      # 메모 작성용 캐릭터 선택
│   ├── Memo/                 # 메모 CRUD, 고정, 다중 삭제, 컨텍스트 메뉴
│   ├── Move/
│   │   ├── Controller/
│   │   ├── Filter/           # FilterView, ChipGroupView, RangeSliderView
│   │   ├── Model/
│   │   ├── Translator/       # 한국어 -> 영어 번역, 커맨드 렌더링
│   │   ├── View/
│   │   └── ViewModel/
│   ├── OnBoarding/           # 버전별 기능 안내
│   ├── Repository/
│   │   ├── Data/             # Repository 구현체, DTO
│   │   ├── Network/          # Supabase, 네트워크 추상화
│   │   └── Persistant/       # Core Data, UserDefaults
│   ├── Settings/
│   ├── Utility/
│   └── Version/
├── TK8Tests/                 # 번역, 커맨드, 필터, 메모 테스트
├── SupabaseAPITests/
└── TK8.xcodeproj/
```

## 테스트

Xcode에서 `TK8Tests` 스킴을 실행하거나, 사용 가능한 시뮬레이터 이름에 맞춰 아래 명령을 사용할 수 있습니다.

```bash
xcodebuild test \
  -project "Tekken8 Frame Data/TK8.xcodeproj" \
  -scheme TK8Tests \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

주요 테스트 범위는 다음과 같습니다.

- `KRToENTranslatorTests`: 섹션, 설명, 입력 문장 번역 회귀 테스트
- `CommandTokenizeTests`: 철권 커맨드 토큰화 테스트
- `MoveListFilteringTests`: 키워드, 섹션, 속성, 프레임 범위 필터 테스트
- `MemoTests`: Core Data 기반 메모 저장, 조회, 수정, 삭제 테스트
