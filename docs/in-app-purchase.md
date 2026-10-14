# 광고 제거 구매 운영과 검증

## 상품과 제공 범위

- Product ID: `remove_ad`, 비소모품, 가족 공유 OFF.
- [App Store Connect 상품](https://appstoreconnect.apple.com/apps/6745224754/distribution/iaps/6819986143)의 미국 기준 가격은 USD 2.99, 국가별 자동 조정. 앱은 `Product.displayPrice`를 표시한다.
- 한 번 구매하면 배너와 기술표 네이티브 광고 및 광고 공간을 제거한다. 같은 App Store 구매 계정의 다른 기기/재설치에서 복원할 수 있다.
- 환불은 [Apple 환불 페이지](https://reportaproblem.apple.com/)에서 고객이 신청하고 Apple이 처리한다. 페이지를 열기만 하면 구매 권한을 회수하지 않는다.

## 권한 계약

StoreKit 자동 검증을 통과한 대상 비소모품 거래만 구매 증거로 사용한다. 구매 boolean을 UserDefaults/Core Data에 저장하지 않는다. `checking/unknown`은 광고 보류, `adFree`는 광고 제거, 정상 조회상 `notPurchased`는 기존 Remote Config·UMP 조건을 적용한다.

초기/foreground에서 현재 권한을 조회하고 앱 수명 동안 거래 갱신을 감시한다. 거래 완료는 즉시 권한을 제공한 뒤 finish한다. 환불 갱신은 현재 권한 전체를 확인해 이전 거래의 환불이 재구매를 회수하지 않게 한다. 취소·pending·검증 실패를 성공으로 기록하지 않는다. 구매/복원 작업을 동시에 실행하지 않는다.

검증된 로컬 구매는 오프라인에서도 유효하다. 최신 환불 반영은 연결 복구 후로 지연될 수 있다. 복원 버튼에서만 `AppStore.sync()`를 호출하고, 강제 동기화 실패로 기존 검증된 구매를 삭제하지 않는다. 확인 실패에는 거래 갱신·앱 복귀·설정 재확인을 사용하며 무한 재시도를 하지 않는다.

## 로컬 검증

1. Xcode에서 `TK8 StoreKit Test` scheme을 선택한다. Run에 `AdRemoval.storekit`이 연결돼 있다. 일반 scheme과 Release 실행에는 연결돼 있지 않다.
2. 설정에서 현지 가격·구매 버튼을 확인하고 구매한다. 배너/네이티브와 광고 공간이 즉시 사라지는지 확인한다.
3. 앱을 종료·재실행하고 구매 완료 상태가 유지되는지 확인한다.
4. Xcode Debug → StoreKit → Manage Transactions에서 환불을 발생시켜 권한 회수·광고 조건 복귀를 확인한다.
5. Ask to Buy, 취소, 실패를 시뮬레이션한다. pending/오류를 구매 완료로 표시하지 않는지 확인한다.
6. 설정 재확인·복원, 앱 복귀, Remote Config 변경이 구매자 광고를 켜지 않는지 확인한다.

자동 테스트는 `TK8Tests` scheme에서 실행한다. `AdRemovalPurchaseTests`는 상태·경쟁·광고 차단을, `AdRemovalStoreKitTests`는 SKTestSession의 실제 로컬 거래·환불을, `NativePurchaseAdTests`는 네이티브 prepare 대기 요청과 재개를 확인한다. `AdRemoval.storekit`은 테스트 fixture이며 앱에 포함돼 있어도 일반/Release StoreKit 거래를 대체하지 않는다.

## Sandbox/TestFlight와 제출 전 확인

- 일반 앱 scheme에서 로컬 StoreKit configuration을 끄고 실기기 Sandbox 계정 또는 TestFlight로 실제 상품 조회·구매를 확인한다.
- 동일 구매 계정으로 재설치·다른 기기 복원, 오프라인 재실행, 환불 후 연결 복구, App Store 계정 변경을 확인한다.
- 소형 기기·큰 글자·다크/라이트에서 구매 상태와 현지 가격·설명을 읽고 모든 설정 행까지 스크롤할 수 있는지 확인한다.
- 첫 비소모성 IAP는 새 앱 버전과 함께 제출한다. 구현된 설정 구매 화면의 심사 스크린샷과 구매/복원 진입 경로를 제공한다.
- 기존 `buy_dlc_to_developer`, `donate_to_developer` 초안은 이번 앱에서 요청하지 않는다.
- 사업자·계약·세금·은행·한국 준수 정보는 운영자 확인 범위다. 서버 없는 검증 방식이 사업자의 세무·소비자보호 책임을 대신하지 않는다.

공식 근거: [StoreKit](https://developer.apple.com/documentation/storekit/in-app-purchase), [권한 조회](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [복원](https://developer.apple.com/documentation/storekit/appstore/sync()), [Apple 환불 안내](https://support.apple.com/ko-kr/118223).


## 2026-10-14 재통합 검증

App/DIContainer · Services/Purchases/Ads · Features/Settings 구조에 완성본을 재통합했다. Xcode 27에서 TK8Tests 172개(로컬 StoreKit 구매·환불 포함)와 일반 scheme Release Simulator build가 통과했다. 테스트 환경은 iPhone 16 Plus/iOS 18.5다. 위의 실기기 Sandbox/TestFlight와 제출 전 확인 항목은 별도로 남아 있다.


## 구매 전 고지와 법적 검토

[구매 안내 검토](purchase-notice-review.md)에 2026-10-14 확인한 한국 소비자보호 규정·Apple 조건, 한/영 구매 안내와 판매 전 미확정 사항을 정리했다. 앱에는 설정 → 광고 제거/구매 안내 → 현지 가격의 구매 버튼 → Apple 결제 화면 순서로 반영했다. 안내 화면은 구매 후에도 열 수 있으며 구매 복원·가격 재확인·Apple 환불 요청/도움말·약관·표준 EULA·App Store 개발자 정보·문의 경로를 제공한다. 메일 설정 여부와 관계없이 문제 신고와 개발자 문의는 한국어/영어 지원 페이지로 연결한다. 외부 페이지나 App Store Connect는 변경하지 않았다. 기능 테스트/빌드 통과가 거래조건 고지·철회 제한 적법성·사업자 책임의 검토 완료를 의미하지 않는다. 자체 환불 불가/포괄적 면책 조항은 도입하지 않는다.

## 출시 전 확인과 담당 범위

| 항목 | 처리 상태 | 확인 방법 / 담당 |
|---|---|---|
| 제공 범위·1회 구매·가격·구매 전 안내 | 앱 반영 | 운영자가 실제 상품명/설명을 같은 범위로 맞춘다. '평생 모든 기능'처럼 확대하지 않는다. |
| 검증 실패·취소·pending·중복·환불 권한 회수 | 구현 및 로컬 테스트 | TestFlight에서 실기기 구매·재설치/계정별 복원·환불·연결 복구 검증을 완료한다. |
| 환불과 기능 장애 지원 경로 | 앱 반영 | Apple 심사 절차 안내, 개발자 이메일 수신/응대 확인. 환불 페이지 접근만으로 권한 회수하지 않는다. |
| App Store 사업자정보·유료 계약·적용 EULA | 사용자 준비 완료 보고, 직접 검증 미완료 | 판매 전 운영자가 실제 공개 표시와 콘솔 상태를 확인한다. 자체 EULA 사용 시 표준 EULA 링크를 조정한다. |
| 한국/판매국 고지·계약내용 제공·철회/환급 의무 분담 | 미확정 | 검토 문서의 구체적인 질문으로 법률 전문가에게 확인. 안내 추가만으로 적법성이 확정되지는 않는다. |
| 철권 명칭·이미지·영상 등 사용/수익화 근거 | 사용자 보고: 개별 허락 없음. 공개 조건 적용 여부 미확정 | [이용 근거 검토와 문의 초안](ip-permission-review.md) 참조. 결제 안내나 비공식 앱 표시만으로 사용 허락을 대신하지 않는다. |

지식재산 검토 근거: [Apple 심사 지침 5.2](https://developer.apple.com/app-store/review/guidelines/#intellectual-property). 특정 자산의 위법성을 이 문서에서 판단하지 않는다.

### 로컬 복원 테스트의 한계

2026-10-14 사용자는 로컬 StoreKit 구매 후 앱 삭제 없이 복원하면 성공하지만 삭제·재설치 후에는 구매 기록 없음이 표시된다고 보고했다. Xcode 로컬 환경은 App Store 계정의 거래 서버와 독립적이다. 앱 삭제로 로컬 거래가 사라진 상황을 실제 계정의 복원 실패로 확정하지 않는다. 실기기 Sandbox/TestFlight에서 같은 구매 계정으로 재설치 복원을 확인한다. [테스트 환경](https://developer.apple.com/documentation/storekit/testing-at-all-stages-of-development-with-xcode-and-the-sandbox), [실제 거래 동기화](https://developer.apple.com/documentation/storekit/appstore/sync()).
