# Settings Appearance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 승인한 설정 시안과 다크 기본/선택형 라이트·시스템 테마를 구현한다.
**Architecture:** AppTheme Repository → 공유 AppAppearance → Scene window 및 설정 picker. 역할별 Asset Catalog 색상을 UIKit/SwiftUI에서 공유한다.
**Tech Stack:** Swift, UIKit, SwiftUI, Combine, UserDefaults, XCTest; iOS 17.0+.
**Spec:** docs/superpowers/specs/2026-10-27-settings-appearance-design.md

## Global Constraints

- 기존 사용자 StoreKit fixture/개인 파일 보존, feat/settings-appearance에서 작업.
- 다크 기본, 라이트/시스템 선택 영속 저장, 역할별 색상/본문 대비, 320pt/최대 글씨/ko·en 유지.
- 데이터/구매/측정 계약과 UIKit/SwiftUI 경계, 버전 유지. 커밋/푸시 없음.

## Review Focus

- 저장 실패/잘못된 저장값/최초 실행 시 다크 기본 유지.
- window/모달/SwiftUI hosting이 즉시 같은 테마를 적용하고 시스템 선택에서 override를 해제.
- 고정 흰 글자와 CALayer.cgColor 경계색이 테마 변경 뒤 남지 않음.
- 기존 설정 구매/문의/광고 개인정보/검사기 접근 보존, 버전 정보 비대화형 이동.
- 작은 화면/큰 글씨에서 picker·설정·기술/메모 콘텐츠가 잘리지 않음.

### Task 1: 테마 상태와 저장

- [x] AppAppearanceTests에 기본값/저장/재생성/시스템/실패/등록 window 변경 테스트 작성, RED.
- [x] AppTheme, DefaultAppThemeRepository, AppAppearance 구현, GREEN.

### Task 2: 설정·picker·Scene 조립

- [x] 설정 그룹/구매 경로/테마 sheet 선택/상태 표시 및 새 window 등록 테스트 작성, RED.
- [x] SettingViewController/SettingTableView 개편, ThemeSelectionViewController/정보 footer 구현, DI/Scene 연결. ko/en 및 navigation 스타일 추가.

### Task 3: 공통 팔레트·검증

- [x] 역할별 색상 대비와 실제 테마 전환 후 텍스트/셀 상태 검증.
- [x] 중립/판정 색상 assets 정의, 캐릭터/기술/메모/필터/구매/영상 상세의 고정 읽기 색상을 교체. 영상 플레이어 배경·이미지 및 강조색 위 흰 글자는 유지.
- [x] 설정·picker/구매/대표 기술·메모의 한국어 기본/최대 글씨 양 테마 이미지 검증, 전체 회귀/Release 빌드/JSON/diff 검사.
- [x] 독립 코드 리뷰와 문서/implementation-notes 갱신, 기존 환경 검증 한계 명시.

## 검증 결과 (2026-10-27)

- iPhone SE 3세대 / iOS 18.5: 전체 회귀 228개 중 227개 성공. 기존 `OnboardingTests.test_lightUpdateScreenShowsOnlyNewFeaturesAndFitsInsideSheet` 크기 검증 1개 실패(변경 전에도 재현). 기존 환경에서 대기하던 StoreKit 실거래 통합 테스트 제외.
- 테마/설정/콘텐츠 신규 13개 전체 회귀에서 통과. 이후 영어·320pt·최대 Dynamic Type picker 검증 1개 추가, 설정 관련 영어 5개 모두 통과. 실제 UIWindowScene에서 SwiftUI dark/light 전환과 이미지 확인.
- Release Simulator 빌드, assets/문구 JSON, project plutil 및 diff 검사 통과. 실기기와 수동 VoiceOver, 실제 StoreKit 거래는 미검증.
- 독립 리뷰의 설정→기술 목록 복귀 시 큰 navigation title 유지 문제를 RED 재현 후 수정. 고정 bundle Dark 설정도 시스템 추종을 막아 제거하고 회귀 테스트 추가.
- 기존 사용자 StoreKit diff 53 additions/24 deletions 및 개인 파일 보존. 앱 버전/빌드 번호 유지. feat/settings-appearance에서 미커밋/미푸시.
- 결과: /private/tmp/tk8-appearance-final.xcresult, /private/tmp/tk8-appearance-english.xcresult, /private/tmp/tk8-appearance-release.log.
