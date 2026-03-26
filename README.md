# 👊🏻 TK8 (Tekken 8 Frame Data)

<img src="https://i.imgur.com/CtWdxoM.png" />

> ### 💡 모르면 맞아야지는 이제 그만! TK8과 함께 기술을 알아봅시다!

<img src="https://i.imgur.com/KmuJszr.png" />

---

## 📱 앱 소개

철권8 캐릭터별 기술 프레임 데이터를 제공하는 iOS 앱입니다.
한국어·영어 동시 지원으로 국내외 사용자 모두 이용 가능합니다.

---

## 🥊 주요 기능

### 캐릭터 검색
- 한국어/영어 이름 기반 캐릭터 필터링

### 캐릭터 별 기술 프레임 정보
- 기술명, 커맨드, 판정, 데미지, 프레임(startup/guard/hit/counter) 제공
- 기술명·커맨드·속성 기반 실시간 검색

### 다국어 지원
- 기기 언어 설정에 따라 한국어/영어 자동 전환
- 한국어로 된 기술 설명을 영어로 번역하여 제공

---

## 🛠 기술 스택

| 분류 | 사용 기술 |
|---|---|
| Language | Swift |
| UI | UIKit + SwiftUI |
| Async | Swift Concurrency (async/await, Actor, TaskGroup) |
| Reactive | Combine |
| Local DB | Core Data |
| Network | Supabase (PostgREST) |
| Analytics | Firebase Analytics |
| Test | XCTest |

---

## 🏗 아키텍처

MVVM + Repository Pattern 기반으로 설계하였습니다.

```
┌─────────────────────────────────┐
│       View (UIKit / SwiftUI)    │
│  CollectionView, DiffableDS     │
└──────────────┬──────────────────┘
               │ Combine (@Published)
┌──────────────▼──────────────────┐
│     ViewModel (@MainActor)      │
│  CharacterListViewModel         │
│  MoveListViewModel              │
└──────────────┬──────────────────┘
               │ Protocol
┌──────────────▼──────────────────┐
│          Repository             │
│  DefaultCharacterRepository     │
│  DefaultMoveRepository          │
└────────┬─────────────┬──────────┘
         │             │
┌────────▼───┐  ┌──────▼─────────┐
│  Supabase  │  │   Core Data    │
│  (Network) │  │  (Local Cache) │
└────────────┘  └────────────────┘
```

### 의존성 관리
`DIContainer`에서 ViewModel·Repository 생성 및 조립을 담당합니다.
각 ViewController는 자신에게 필요한 의존성만 주입받습니다.

---

## 💡 주요 구현 사항

### CoreData 오프라인 캐싱 + 스키마 버전 관리
- 최초 실행 시 Supabase에서 데이터를 받아 Core Data에 캐싱
- 이후 실행부터는 로컬 캐시 우선 사용으로 불필요한 트래픽 제거
- 앱 로컬 스키마 버전과 서버 DB 버전 비교 후 낮을 경우에만 자동 재패치

### 한국어→영어 규칙 기반 번역 엔진
- 철권8 기술 설명의 한국어 전용 게임 문법을 영어로 변환
- NSRegularExpression 기반 4단계 파이프라인(고정사전 → 접두 컨텍스트 → 핵심 패턴 → 꼬리 패턴)
- `KRToENTranslatorTests`로 패턴 추가·수정 시 회귀 검증 자동화
- 번역 기능 적용 후 국내:해외 다운로드 비율 2:1 → 1:1 개선

### 이미지 캐싱
- 메모리·디스크 캐싱 적용으로 초기 1회 이후 네트워크 요청 제거
- ViewModel 선처리 방식으로 이미지 로딩을 View 생명주기에서 분리

### Swift Concurrency 활용
- `withTaskGroup`으로 기술 목록 전체를 병렬 번역
- `NSCache` + Box 패턴으로 번역 결과 캐싱 (스레드 안전 + 자동 메모리 관리)

---

## 🗂 폴더 구조

```
TK8/
├── Character/
│   ├── Controller/
│   ├── ViewModel/
│   └── View/
├── Move/
│   ├── Controller/
│   ├── ViewModel/
│   ├── Model/
│   ├── View/
│   └── Translator/       # 한국어→영어 번역 엔진
├── Repository/
│   ├── Network/          # Supabase
│   └── Persistant/       # Core Data, UserDefaults
├── Settings/
└── Utility/
    ├── DIContainer.swift
    └── ImageCacheManager.swift
```
