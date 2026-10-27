# Ad Removal Notice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** #101 캐릭터 선택 화면 배너 위에 일회성 광고 제거 안내를 제공한다.

**Architecture:** 안내 전용 UIKit View/ViewModel과 UserDefaults Repository를 DI에서 조립한다. BannerAdHost의 선택적 accessory가 실제 배너와 함께 나타나며 구매 화면 생성 경로를 재사용한다.

**Tech Stack:** Swift, UIKit, Combine, UserDefaults, XCTest, iOS 17.0+.

**Spec:** docs/superpowers/specs/2026-10-27-ad-removal-notice-design.md

## Global Constraints

- 기존 StoreKit fixture 변경과 untracked 개인 파일 보존; 현재 feat/#101/ad-removal-discovery-notice에서 작업한다.
- 버전 변경·커밋·푸시·PR·머지는 이번 구현 범위에 포함하지 않는다.
- 한국어/영어 현지화, Dynamic Type, 다크 모드, 44pt 버튼 터치 영역.
- 안내 상태는 구매 권한과 분리하며 Analytics 계약을 변경하지 않는다.

## Review Focus

- 권한 checking/unknown은 안내를 잠깐도 표시하지 않는다.
- 광고 로딩 전·실패·키보드·원격 중단·화면 이탈에서 공간이 남지 않는다.
- 구매 완료·복원 후 안내/광고가 함께 사라진다.
- 닫기/알아보기 후 화면 재생성·재실행에도 다시 표시하지 않는다.
- 큰 글씨/작은 화면에서 X/알아보기와 배너가 겹치지 않는다.

### Task 1: 안내 상태와 영속 저장

**Files:** Data/Repositories/AdRemovalNoticeRepository.swift, Features/Character/ViewModel/AdRemovalNoticeViewModel.swift, TK8Tests/AdRemovalNoticeTests.swift (모두 앱 루트 하위).

**Interfaces:** Repository의 `isConsumed: Bool`, `consume()`; ViewModel의 `@Published isEligible: Bool`, `consume()`와 구매 서비스 구독.

- [x] XCTest: 최초 미구매 자격, checking/unknown/adFree 차단, 권한 변경 즉시 반영, 보기만 하면 유지, 소비 후 재생성 차단 테스트 작성 후 RED 확인.
- [x] 기존 UserDefaultsManageable을 쓰는 Repository 및 ViewModel 구현, 동일 테스트 GREEN 확인.

### Task 2: 안내 View와 배너 호스트

**Files:** Features/Character/View/AdRemovalNoticeView.swift, Services/Ads/BannerAdHost.swift, TK8Tests/BannerAdTests.swift, TK8Tests/AdRemovalNoticeTests.swift.

**Interfaces:** `BannerAdHost(..., accessoryView: UIView? = nil, ...)`; accessory의 `isHidden`을 화면에서 바인딩하면 스택이 공간을 접는다. `AdRemovalNoticeView(onLearnMore:onClose:)`.

- [x] 배너 로딩 전 공간 없음, 성공 후 안내 높이 예약, 안내만 닫으면 배너 유지, 실패/중단 시 전체 접힘, 재시도 복원 테스트 작성 후 RED 확인.
- [x] 부속 뷰를 별도 스택 영역에 배치하고 기존 배너 lifecycle 유지. View는 작은 폭/큰 글씨에서 세로 배치하도록 구현. GREEN 확인.

### Task 3: 조립·구매 경로·문서·검증

**Files:** App/DIContainer.swift, Features/Character/Controller/CharacterListViewController.swift, Features/Settings/Controller/SettingViewController.swift, Localizable.xcstrings, docs/architecture.md, implementation-notes.md.

**Interfaces:** DI `makePurchaseNoticeViewController()`, 캐릭터 화면의 안내 ViewModel 바인딩 및 navigation.

- [x] 실제 캐릭터 화면의 알아보기 push/소비와 접근성 큰 글씨 레이아웃 테스트를 추가하고 RED 확인.
- [x] DI 조립과 기존 설정 구매 경로 재사용, 한국어/영어 문구 추가, architecture 책임 설명 갱신.
- [x] 관련 테스트, TK8Tests 전체, Release Simulator 빌드, JSON 검사와 git diff --check 실행.
- [x] 별도 최종 코드 리뷰로 조건/레이아웃/비동기 상태 확인 후 결과·한계를 implementation-notes 및 사용자에게 보고.

## 실행 결과 — 2026-10-27

- 현재 요청된 기능 브랜치에서 직접 구현. 커밋/푸시/PR 없음.
- RED: 신규 ViewModel/Repository, accessory 인자, View 및 화면 연결 미구현으로 실패하는 것을 확인한 뒤 구현.
- Task 1: 영속 저장·권한 전환 테스트 통과.
- Task 2: 배너 로딩 전/성공/실패/접기/재시도 및 안내만 닫기 테스트 통과. UIStackView 숨김 뒤 좌표 검사는 스택/부모 레이아웃 갱신 후 수행.
- Task 3: 기존 구매 화면 push 및 처리 상태 저장, 한국어 실제 window의 320×568 기본 글씨/최대 Dynamic Type 조합 검증. 안내·배너 관련 16개 테스트 통과.
- 회귀: TK8Tests 중 StoreKit 통합 테스트를 제외한 209개 실행, 208개 성공/기존 OnboardingTests.test_lightUpdateScreenShowsOnlyNewFeaturesAndFitsInsideSheet 1개 실패. HEAD 원본 사본에서도 같은 온보딩 크기 assertion 4건 실패 재현. 첫 병렬 실행에서는 동일 온보딩 실패 및 테스트 앱 재시작 오류가 있어 순차 실행으로 확인.
- StoreKit 통합 테스트는 변경본/HEAD 사본 모두 SKTestSession을 포함한 실행이 진행되지 않아 중단. 이번 기능의 구매 권한/화면 연결 테스트는 통과했으나 실제 거래 통합 검증을 대체하지 않음.
- Release generic iOS Simulator 앱 빌드, String Catalog JSON 검사, git diff --check 통과.
- 독립 리뷰: material findings 없음. 실제 안내/배너 조합 검증 공백은 실제 window·한국어·최대 폰트 크기 assertion 및 이미지 검증으로 보완. 수동 VoiceOver 및 실기기/실제 광고 소재는 미검증.
- 로그/결과는 /private/tmp/tk8-issue101-{regression,window-ui,release,baseline-onboarding}.* 참조.
