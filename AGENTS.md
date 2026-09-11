# AGENTS.md

## 기준 문서

- 코드나 프로젝트 설정을 변경하기 전에 `docs/architecture.md`를 읽고 현재 기술 스택, 모듈 경계, 데이터 흐름을 기준으로 삼는다.
- 문서와 구현이 다르면 실제 코드와 Xcode 설정을 확인하고 불일치를 함께 정리한다.
- 모듈 책임, DI 조립, 폴더·target·scheme, Repository·캐시 흐름, Core Data·Supabase·UserDefaults 역할, 핵심 의존성 또는 테스트 전략이 바뀌면 같은 변경에서 `docs/architecture.md`를 갱신한다.
- 위 구조가 바뀌지 않는 UI 조정, 국소 버그 수정, 테스트 보강에는 아키텍처 문서 변경을 만들지 않는다.

## 구조와 책임

- UIKit ViewController는 화면 생명주기, navigation, binding, data source 연결을 담당한다.
- ViewModel은 화면 상태와 사용자 액션을 다루며 구체적인 네트워크나 Core Data 구현에 직접 의존하지 않는다.
- 데이터 출처 선택과 DTO·영속 모델 매핑은 Repository 경계 안에 둔다.
- 앱 조립과 구현체 주입은 `Tekken8 Frame Data/TK8/Utility/DIContainer.swift`를 중심으로 유지한다.
- 명시적인 구조 변경 요청이 없다면 UIKit 화면과 SwiftUI 구성 요소의 현재 경계를 유지한다. 경계를 변경하면 책임과 데이터 흐름을 검토하고 `docs/architecture.md`를 함께 갱신한다.

## 데이터와 보안

- 캐릭터와 기술 데이터는 Core Data 캐시를 우선 사용하고, 캐시가 비었거나 버전 갱신으로 무효화된 경우에만 Supabase에서 다시 가져오는 흐름을 보존한다.
- 프레임 데이터 캐시를 무효화할 때 사용자 메모인 `MemoEntity`는 삭제하지 않는다.
- 메모 CRUD와 import·export를 변경하면 UUID와 `updatedAt` 기준 merge 동작을 함께 확인한다.
- `GoogleService-Info.plist`, `Secrets.xcconfig`, Supabase key, `.env.local` 등 secret이나 로컬 설정을 커밋하지 않는다.
- 기존 사용자 변경을 되돌리지 않고 관련 없는 파일을 수정하거나 커밋하지 않는다.

## UI와 현지화

- UIKit과 SwiftUI가 섞인 기존 화면 구조와 iOS 17.0 최소 지원 버전을 유지한다.
- 사용자에게 보이는 문구를 추가하거나 변경하면 `Tekken8 Frame Data/TK8/Localizable.xcstrings` 반영 여부를 확인한다.
- 화면 변경에서는 작은 기기, 다크 모드, Dynamic Type 영향을 고려한다.

## Analytics

- Analytics 이벤트나 수집 정책을 변경하기 전에 `docs/analytics-measurement.md`를 확인한다.
- 검색어 원문, 메모 내용, 사용자 식별자를 Analytics 파라미터로 전송하지 않는다.
- 저장 성공 이벤트는 Repository 쓰기가 실제로 성공한 뒤에만 기록한다.
- 이벤트 이름, 파라미터 또는 성공·실패 판정 계약을 바꾸면 측정 문서와 관련 테스트를 함께 갱신한다.

## 검증

- 작은 로직 수정은 직접 관련된 테스트를 우선 실행한다.
- 공통 ViewModel, Repository 또는 Core Data 변경은 관련 테스트와 `TK8Tests` 전체를 실행한다.
- DI, target, package 또는 Xcode 프로젝트 설정 변경은 전체 테스트와 앱 빌드를 확인한다.
- 문서와 설정만 변경하면 해당 형식의 문법 검사와 `git diff --check`를 실행한다.
- 실행하지 못한 검증은 이유와 미검증 범위를 PR에 기록한다.
