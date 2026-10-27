# Purchase Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 설정 광고 제거 진입점을 하나로 통합하고 구매 화면의 정보 계층을 정리한다.

**Architecture:** 기존 SettingsPurchaseViewModel/구매 서비스를 재사용한다. PurchaseNoticeViewController는 간결한 구매 화면, 새 PurchaseInformationViewController는 상세 안내/외부 링크를 담당한다.

**Tech Stack:** UIKit, Combine, XCTest, iOS 17.0+.

**Spec:** docs/superpowers/specs/2026-10-27-purchase-screen-design.md

## Global Constraints

- 현재 사용자 요청 브랜치에서 이전 #101 변경과 StoreKit fixture/개인 파일 보존. 커밋/푸시/PR/버전 변경 없음.
- 한국어/영어, Dynamic Type, 320pt, 다크 모드, 44pt 이상 버튼 터치 영역.
- StoreKit 권한/Analytics 계약은 유지하며 상세 설명과 환불/문의 접근을 보존한다.

## Review Focus

- pending/unknown/구매 완료에서 재구매 버튼이 활성화되지 않는다.
- 가격 조회 중 재시도/가격 오류를 성급하게 표시하지 않는다.
- 상세 안내를 열고 돌아와도 거래를 시작하지 않는다.
- 구매/복원 결과 메시지가 화면 전환 중 중복되거나 유실되지 않는다.
- 작은 화면/큰 글씨에서 버튼과 문구가 잘리지 않는다.

### Task 1: 동작 계약 테스트

**Files:** TK8Tests/AdRemovalPurchaseTests.swift (프로젝트 하위).

- [x] 설정 기본 4행/광고 진입점 1개 및 구매 상태 변경 테스트 수정.
- [x] 구매→별도 상세 안내, 구매 CTA 가격/완료 상태, 재시도 조건, 상세 환불/문의 및 한국어 이미지 테스트 추가. RED 확인.

### Task 2: UI와 조회 상태 구현

**Files:** Features/Settings/Controller/{SettingViewController,PurchaseNoticeViewController,PurchaseInformationViewController}.swift, Features/Settings/ViewModel/SettingsPurchaseViewModel.swift, Localizable.xcstrings.

- [x] 설정 네 항목을 하나로 통합. 새 상세 화면에 기존 안내/링크를 섹션별 이동.
- [x] 간결한 혜택 카드/강조 구매 버튼/복원·상세 보조 액션 구현.
- [x] ViewModel의 isPreparing/shouldOfferRetry로 조회 중과 오류 표시를 구분하고 ko/en 문구 추가. 관련 테스트 GREEN 확인.

### Task 3: 검증과 문서

- [x] 한국어 320pt 기본/최대 글씨·두 테마의 실제 window 이미지 확인.
- [x] 관련 테스트와 전체 TK8Tests(기존 StoreKit 통합 대기는 별도 보고), Simulator 앱 빌드, JSON/diff 검사.
- [x] 별도 코드 리뷰, architecture 및 implementation-notes에 변경·검증·한계 기록.

## 실행 결과 — 2026-10-27

- 설정의 광고 관련 4행을 단일 광고 제거 행으로 통합. 구매 화면은 혜택 카드/실제 가격 CTA/1회 결제 문구와 복원/상세 안내로 구성. 상세 화면에 기존 설명 5문단과 환불/약관/문의 링크 보존.
- 새 동작 계약의 미구현 RED 확인 후 구현. 최대 글씨에서 primary 버튼 폰트가 17pt로 고정되는 실패를 추가 assertion으로 재현했고, trait-aware transformer/멀티라인 설정 후 GREEN 확인.
- 독립 리뷰의 P2: 서로 다른 화면이 가격을 동시에 조회할 때 두 번째 화면이 진행 중인 요청을 실패로 표시할 수 있음. 공유 AdRemovalPurchaseService productTask를 await하도록 수정. 두 ViewModel의 동일 요청 대기 테스트 RED→GREEN, 최종 관련 suite 통과.
- 상세 안내 복귀 테스트는 scene 없는 window/전환 직후 검사에서 실패해 실제 UIWindowScene 연결 및 복귀 뒤 검사로 보완. 생산 코드의 메시지 처리 계약은 유지.
- 최종 한국어 전체 회귀: StoreKit 실거래 통합(앞선 실행에서 환경 대기) 제외 215개 실행, 214개 성공/기존 OnboardingTests.test_lightUpdateScreenShowsOnlyNewFeaturesAndFitsInsideSheet 1개 실패(크기 assertion 8건). 구매 관련 27개 통과, 안내/배너/구매 권한 회귀 통과.
- Release generic Simulator 앱 빌드, String Catalog JSON, git diff --check 통과. 한국어 320pt 기본/최대 글씨와 양 테마의 실제 window 이미지 검증.
- 테스트 종료 후 Xcode의 simctl diagnose 수집이 지연돼 해당 검증 자식 프로세스만 중단, 완료된 .xcresult 저장 및 214/1 결과 확인. 테스트 실행을 중단한 것은 아님.
- 실제 StoreKit 거래, 실기기, 수동 VoiceOver는 별도 검증. 커밋/푸시/PR/버전 변경 없음. 기존 사용자 StoreKit fixture 변경 보존.
- 검증: /private/tmp/tk8-purchase-final.xcresult, /private/tmp/tk8-purchase-final-release.log. 이미지: /private/tmp/tk8-purchase-final-attachments/.
