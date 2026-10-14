# 광고 제거 구매 안내 검토와 문구 초안

- 확인일: 2026-10-14
- 상태: 한국어/영어 요약 안내를 앱의 구매 안내 화면에 반영했다. App Store Connect·외부 웹사이트·자체 EULA·권리 포기 동의는 변경하지 않았다. 아래 법적 적용 판단은 계속 검토 대상이다.
- 범위: Apple 인앱결제로 제공하는 `remove_ad` 비소모품의 구매 전 안내, 복원, 환불, 한국 소비자보호 관련 검토. 전 판매 국가의 법률 검토 완료 문서가 아니다.
- 원칙: 사실과 소비자 권리를 안내한다. 자체 환불 불가 정책이나 법정 권리 포기 동의를 추가하지 않는다. 이 문서가 법적 적합성을 보증하지는 않는다.

## 확인된 근거와 적용상 남은 판단

| 근거 | 확인한 내용 | 이 앱에서의 적용 방향 / 미확정 사항 |
|---|---|---|
| 전자상거래법 제13조 | 적용 대상 통신판매업자에게 신원·가격·공급·철회/환불·불만 처리·약관 등 구매 전 정보 제공을 요구한다. 미성년자 거래 취소권 고지도 규정한다. | App Store 거래 구조에서 Apple과 개발자의 해당 의무 분담, 상품 페이지와 앱/웹 안내로 충족되는 범위는 별도 확인한다. 사업자등록 완료만으로 화면 고지가 완료됐다고 판단하지 않는다. |
| 전자상거래법 제17조 제1·2·3·6항 및 시행령 제21조의2 | 원칙적 7일 청약철회, 디지털콘텐츠 제공 개시 등 제한 사유, 제한 시 표시·시험 사용 등 조치, 표시/광고와 다르게 제공된 경우의 별도 권리를 규정한다. | 광고 제거 기능이 어떤 용역/디지털콘텐츠에 해당하고 제한 요건을 충족하는지 확정하지 않았다. 무료 앱 사용이 유료 광고 제거의 적법한 체험 요건을 자동 충족한다고 주장하지 않는다. 자체 '제공 즉시 환불 불가' 조건을 도입하지 않는다. |
| 전자상거래법 제18조·제35조, 약관규제법 제6·7조 | 철회에 따른 환급 의무, 관련 주체의 연대책임 규정, 소비자에게 불리한 권리 제한 약정과 부당한 면책의 효력 제한이 있다. | '모든 환불/법적 책임은 Apple에 있음', '어떤 경우에도 환불 불가', '장애/종료에 책임 없음' 같은 문구를 쓰지 않는다. Apple 처리 창구와 개발자의 기능 제공/지원 책임을 구분한다. |
| Apple 한국 미디어 서비스 약관 A·B·O | 한국 App Store 환불에 전자상거래법을 적용한다고 안내한다. 별도 EULA가 없으면 표준 EULA가 적용되고 타사 앱의 콘텐츠·지원 책임은 앱 제공업체에 있다. | Apple을 통한 결제·환불 접수 경로를 안내하되 법령에 따른 권리를 남긴다. 자체 EULA가 반드시 있어야 하는 것은 아니다. |
| Apple 환불 지원 문서 | 환불은 요청 후 심사하며 국가별 적합성과 소비자보호법상 권리가 다를 수 있다. | '무조건 환불'도 '개발자가 임의로 승인/거절'도 약속하지 않는다. 단순 페이지 방문을 권한 회수 사유로 삼지 않는다. |
| Apple 한국 준수 정보 안내 | 개발자 유형에 따른 연락처/사업자 정보의 수집·검증 및 상품 페이지 표시를 안내한다. | 사용자는 판매 준비 완료라고 보고했다. 이번 검토에서는 계정의 실제 입력값·공개 표시를 직접 검증하지 않았다. 공개 페이지 또는 콘솔에서 확인한다. |

한국 법령 조회는 korean-law-mcp의 search_law → get_law_text로 수행했다. 전자상거래법 MST 282793 및 시행령 MST 288143의 2026-07-21 시행본, 약관규제법 MST 260021의 2024-08-07 시행본, 민법 MST 284415의 제5조를 확인했다. 조회 서비스가 안내하는 2027-01-21 시행 예정 개정본을 현재 적용본과 혼동하지 않는다. 판매 시작 전 법령과 Apple 약관을 다시 확인한다.

## 현재 화면에서 확인된 공백

설정의 광고 제거와 구매 안내 행은 스크롤 가능한 구매 안내 화면을 연다. 현지 가격·1회 구매·제공 범위·적용 시점·복원 조건·가족 공유 미지원·환불 승인 후 권한 회수·소비자 권리를 안내한다. 그 화면의 구매 버튼을 눌러야 시스템 결제 화면이 열린다. 상태/가격이 미확정이거나 거래 중이면 구매 버튼을 사용할 수 없다.

구매 전/후 복원·재확인·Apple 환불 요청·환불 도움말·Apple 지역별 약관·표준 EULA·App Store 개발자 정보·문의에 접근할 수 있다. 메일 설정과 관계없이 지원 페이지에서 한국어/영어 문의 안내와 이메일을 확인할 수 있다. App Store 링크 제공은 사업자정보가 적법하게 공개됐음을 검증한 것이 아니다. 자체 EULA가 있다면 표준 EULA 링크와 충돌하지 않도록 판매 전에 조정해야 한다. 코드/테스트 통과가 고지 의무의 완료를 뜻하지 않는다.

## 안내 화면과 외부 웹페이지의 구분

별도 사업자정보 웹사이트나 구매 안내 웹페이지가 Apple IAP의 일률적인 필수 조건이라고 판단한 것은 아니다. 여기서 '페이지'는 앱 내부 화면도 포함한다. 구매 안내는 앱 내부에서 제공할 수 있다. 사업자정보는 App Store Connect의 한국 준수 정보와 실제 상품 페이지 표시를 우선 확인하고, 이 거래에 추가로 요구되는 표시가 있는지 검토한다. 별도 공개 페이지는 이미 존재하는 정보 재사용 또는 접근성 보강 수단 중 하나다. 외부 사이트 개설을 전제하지 않는다.

사용자는 이 차이를 질문했으며 별도 사업자정보 사이트 개설을 요청하거나 승인하지 않았다.

## 권장 표시 위치

1. 설정의 광고 제거 행 → 스크롤 가능한 구매 안내 화면 → 현지 가격이 표시된 구매 버튼 → Apple 결제 확인 화면.
2. 구매 안내에서 복원, 환불 안내, 개발자 문의, 적용 약관에 구매 전 접근 가능하게 한다. 사업자정보는 App Store에 표시되는 정보와 추가 고지 필요 범위를 확인한 뒤 접근 경로를 정한다. 구매 후에도 설정에서 다시 볼 수 있게 한다.
3. App Store 상품명·설명·앱 내 문구를 같은 제공 범위로 맞춘다. 가격은 StoreKit displayPrice를 표시하고 Apple 최종 결제 화면의 금액을 확인하게 한다.
4. 긴 안내를 개인정보처리방침에만 숨기지 않는다. 개인정보처리방침, 구매 안내, EULA는 서로 목적이 다르다.
5. '안내 확인' 체크박스는 법정 청약철회권 포기나 모든 법적 책임 면제로 쓰지 않는다. 디지털콘텐츠 제한을 별도로 적용하려면 조건·표시·시험 사용·증빙 및 해외 판매 지역 요건을 먼저 검토한다.

이 구성은 정보 접근성을 높이기 위한 구현 제안이며, 특정 법적 의무가 이 UI만으로 모두 충족된다는 결론이 아니다.

## 구매 전 요약 문구 — 한국어 초안

> **광고 제거 · 1회 구매**
>
> 이 앱의 배너 광고와 기술 목록의 네이티브 광고를 제거합니다. 구독이 아니며 자동 갱신되지 않습니다. 가격은 구매 버튼과 Apple 결제 확인 화면에서 확인하세요.
>
> 구매가 완료되고 확인되면 광고 제거 기능이 적용됩니다. 승인 대기 또는 결제 오류 상태에서는 구매가 완료된 것으로 처리되지 않습니다. 기능이 적용되지 않으면 구매 복원을 시도하거나 개발자에게 문의해 주세요.
>
> 동일한 App Store 구매 계정을 사용하는 지원 기기에서 구매를 복원할 수 있습니다. 다른 Apple 계정으로의 이전과 가족 공유는 지원하지 않습니다. 구매와 복원에는 인터넷 연결이 필요할 수 있습니다.
>
> 환불은 Apple의 '문제 신고' 페이지에서 요청할 수 있습니다. 환불 가능 여부와 처리에는 적용 법령 및 Apple의 절차가 적용되며, 요청했다고 자동 승인되는 것은 아닙니다. 환불이 승인되어 구매 권한이 회수되면 광고 제거 기능이 해제됩니다. 구매한 기능이 정상 제공되지 않는 경우에는 개발자에게도 문의해 주세요.
>
> 법정대리인의 동의 없이 이루어진 미성년자의 구매는 관련 법령에 따라 미성년자 본인 또는 법정대리인이 취소할 수 있습니다. 이 안내는 관련 법령에 따른 청약철회·환불 등 소비자의 권리를 제한하지 않습니다.

연결 항목: 구매 복원 / Apple 환불 요청 / 개발자 문의 / 사업자정보 / 적용 약관.

'인터넷 연결이 필요할 수 있음'은 기존 검증된 구매를 오프라인에서 무효화한다는 뜻이 아니다. 광고 제거를 Analytics 수집 중단으로 설명하지 않는다. 구매 후에도 현재 Analytics 정책은 별도로 적용된다.

## Purchase notice — English draft

> **Remove Ads · One-time purchase**
>
> Removes banner ads and native ads in the move list in this app. This is not a subscription and does not renew automatically. Check the price on the purchase button and Apple's payment confirmation screen.
>
> Ad removal is enabled once the purchase is completed and verified. A pending or failed payment is not treated as a completed purchase. If ad removal is not enabled, try Restore Purchases or contact the developer.
>
> Purchases can be restored on supported devices using the same App Store purchase account. Transfer to another Apple Account and Family Sharing are not supported. An internet connection may be required to purchase or restore.
>
> You can request a refund through Apple's Report a Problem page. Refund eligibility and processing are subject to applicable law and Apple's procedures; submitting a request does not guarantee approval. Ad removal is disabled if a refund is approved and the purchase entitlement is revoked. Contact the developer if the purchased feature does not work as described.
>
> Rights to cancel purchases by minors made without their legal representative's consent apply where provided by applicable law. This notice does not limit statutory consumer rights, including withdrawal and refund rights.

한국어 초안과 동일한 기능 범위를 설명하는 영문 초안이다. 판매 국가 전체의 철회 제한 동의나 계약 요구사항을 충족했다는 선언이 아니다.

## 표준 EULA와 별도 구매 안내

Apple 표준 EULA를 사용하는 경우에도 앱에서 실제 판매하는 기능과 지원·복원·환불 경로를 구체적으로 안내하는 것을 권장한다. 자체 전체 이용약관을 작성해야만 IAP를 제공할 수 있다고 판단하지 않는다.

자체 EULA를 App Store Connect에 등록하려면 Apple 최소 조항과 판매 국가의 적용 법률을 충족해야 한다. 이 구매 안내 초안을 자동으로 '자체 EULA'로 등록하거나 Apple 표준 EULA를 대체하지 않는다.

## '영구' 표시와 서비스 종료

1회 구매와 평생 앱 운영·모든 미래 기능 제공은 같은 약속이 아니다. 다만 '영구 광고 제거'로 이미 판매했다면 나중에 약관으로 그 권리를 임의로 축소할 수 있다고 주장하지 않는다.

새 판매 표시를 '광고 제거 · 1회 구매'로 명확히 하는 방안을 권장한다. 현재 App Store Connect 상품명/설명도 확인해 문구를 맞춰야 한다. 이번 검토에서는 외부 상품 설정을 변경하지 않았다.

서비스 종료·장기 장애 시 소비자 안내와 구제 방침은 별도로 정하고 검토한다. '언제든 종료할 수 있으며 환불하지 않는다' 같은 포괄적 면책 조항을 추가하지 않는다. 미래 기능의 별도 판매 여부도 현재 광고 제거 제공 범위와 모순되지 않게 검토한다.

## 판매 전 미확정 항목

- App Store에 공개된 개발자/사업자정보의 정확성 및 이 거래에 추가로 필요한 표시 범위를 확인한다. 사용자 판매 준비 완료 보고를 유지한다. 별도 웹사이트 개설을 필수로 요구하지 않는다.
- 청약철회 제한을 적용할지: 현재 제안은 자체 '환불 불가' 정책을 도입하지 않는 것이다. 적용을 원하면 광고 제거 상품의 법적 분류와 법 제17조/시행령 제21조의2 요건을 법률 전문가에게 확인한다.
- 개발자 문의 경로: 앱의 문제 신고/개발자 문의가 지원 웹페이지를 열도록 반영했다. 실제 메일 수신과 응대 절차는 운영자가 확인한다. 기능 제공 불만을 Apple에만 돌려보내지 않는다.
- 한국 원칙적 7일 철회 기간과 디지털콘텐츠 예외, 표시/계약 불일치의 별도 철회 기간(공급 후 3개월·인지 후 30일)은 상세 안내/Apple 약관으로 확인 가능하게 한다. 초안 요약만으로 모든 고지·계약서 교부가 완료됐다고 판단하지 않는다.
- 현재 판매 국가와 Apple/개발자 역할, 증빙/계약내용 제공·거래기록 관리 의무, 서비스 종료 시 구제 정책의 최종 검토. 자체 서버가 없다는 사정만으로 면제된다고 판단하지 않는다.
- 결제 기능의 실기기 Sandbox/TestFlight 검증 및 환불 후 권한 반영 확인.

**구체적인 최종 검토 질문:** “한국 개인사업자가 Apple IAP로 판매하는 비소모성 광고 제거 상품에서 Apple의 상품 페이지/영수증/환불 창구와 이 앱의 구매 안내로 제13조 고지·계약내용 교부 의무가 어떻게 충족되는가? 제17조 디지털콘텐츠 예외를 적용하려면 추가로 무엇이 필요한가? 제18조상 개발자 환급·지원 의무는 어느 범위인가?”

## 출처

- [전자상거래법 제13조](https://www.law.go.kr/LSW/lsSideInfoP.do?docCls=jo&joBrNo=00&joNo=0013&lsiSeq=282793&urlMode=lsScJoRltInfoR)
- [전자상거래법 제17조](https://www.law.go.kr/LSW/lsSideInfoP.do?docCls=jo&joBrNo=00&joNo=0017&lsiSeq=282793&urlMode=lsScJoRltInfoR)
- [전자상거래법 제18조](https://www.law.go.kr/LSW/lsSideInfoP.do?docCls=jo&joBrNo=00&joNo=0018&lsiSeq=282793&urlMode=lsScJoRltInfoR)
- [전자상거래법 제35조](https://www.law.go.kr/LSW/lsSideInfoP.do?docCls=jo&joBrNo=00&joNo=0035&lsiSeq=282793&urlMode=lsScJoRltInfoR)
- [전자상거래법 시행령 제21조의2](https://law.go.kr/LSW/lsLinkCommonInfo.do?lspttninfSeq=63484)
- [약관규제법](https://www.law.go.kr/법령/약관의규제에관한법률)
- [Apple 한국 미디어 서비스 이용약관](https://www.apple.com/legal/internet-services/itunes/kr/terms.html)
- [Apple 환불 요청 안내](https://support.apple.com/ko-kr/118223)
- [Apple 표준/자체 EULA 안내](https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement/)
- [Apple 한국 준수 정보](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information)
- [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) — 자체 EULA 최소 조항·현지법 준수 확인용.
