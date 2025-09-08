//
//  KRToENTranslator.swift
//  TK8
//

import Foundation

struct KRToENTranslator {
    // 1) 고정 치환 (오탈자 포함 교정 가능)
    static let fixedDict: [(pattern: String, replace: String)] = [
        ("레이지 아츠", "Rage Art"),
        ("히트 상태의 남은 시간을 소비", "Partially uses remaining Heat time"),
        ("히트 상태 지속 중에는 파워 상승", "Power up during Heat"),
        ("히트 대시 발동 시에는 이행하지 않음", "Does not shift when using Heat Dash"),
        ("효과 지속 중에는 가드할 수 없음", "Cannot block (attacks taken will count as counter hit)"),
        ("가드 데미지 있음", "Chip damage on block"),
        ("가드 대미지 있음", "Chip damage on block"),
        ("상대의 공격을 받아내면 파워 상승\\(가드 데미지 증가\\)", "Absorb an attack to power up (chip damage on block)"),
        ("펀치 흘리기 효과 있음", "Punch parry effect"),
        ("하단 흘리기 효과 있음", "Has low parry effect"),
        ("킥 흘리기 효과 있음", "Has kick parry effect"),
        ("방어 행동 관통 효과 있음", "Has reversal break effect"),
        ("빠르게 입력하면 파워 상승", "Power up with quick input"),
        ("홀드하면 파워 상승", "Hold at last step to power up"),
        ("홀드 가능", "can hold"),
        ("저스트", "Perfect Input"),
        // 단건 문장들
        ("정면 히트 시 잡기로", "Throw when hit from the front"),
        ("히트 시 잡기로", "on hit shift to throw"),
        ("히트 시 상대의 회복 가능 게이지를 없앰", "Erases opponent’s recoverable health on hit"),
        ("상대의 공격을 받아내면 파워가 상승하고 가드 대미지 추가", "Absorb an attack to power up (chip damage on block)"),
    ]

    // 2) 접두 컨텍스트(복수 가능) 추출 규칙
    //  - 앞에서부터 반복적으로 빼내며 누적: "히트 상태에서" + "몸을 숙인 상태에서" ...
    //  - 불릿(-, –, •, ·) 허용
    static let leadingContexts: [(NSRegularExpression, (NSTextCheckingResult, inout String) -> String)] = {
        var arr: [(NSRegularExpression, (NSTextCheckingResult, inout String) -> String)] = []

        // (더 구체적) 히트 발동 가능 상태에서 → When Heat activation available
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*히트\s*발동(?:이)?\s*가능(?:한)?\s*상태에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "When Heat activation available" }
        ))
        // 히트 상태에서 → During Heat
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*히트\s*상태에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "During Heat" }
        ))
        // 레이지 상태에서 → During Rage
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*레이지\s*상태에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "During Rage" }
        ))
        // 몸을 숙인 상태에서 → While crouching
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*몸을\s*숙인\s*상태에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "While crouching" }
        ))
        // 일어나며 → While rising
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*일어나며\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "While rising" }
        ))
        // 상대에게 등을 보일 때 → Back facing opponent
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*상대에게\s*등을\s*보일\s*때\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Back facing opponent" }
        ))
        // 상대 왼쪽/오른쪽/뒤에서 → Approach opponent from left/right/behind
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*상대\s*왼쪽에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Approach opponent from left side" }
        ))
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*상대\s*오른쪽에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Approach opponent from right side" }
        ))
        arr.append((
            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*상대\s*뒤에서\s*"#),
            { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Approach opponent from behind" }
        ))
        let dynDuring = try! NSRegularExpression(
            pattern: #"^\s*[-–•·]?\s*([^\s].*?)\s*도중(?!\s*에도\s*사용\s*가능)\s*"#)
        arr.append((dynDuring, { m, s in
            let rawName = (s as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let name = stanceNameKRtoEN(rawName) // 네 별칭 함수
            s.removeSubrange(Range(m.range, in: s)!)
            return "During \(name)"
        }))
//        // 동적: "<임의문자> 도중" → "during <…>"  (불릿 허용)
//        arr.append((
//            try! NSRegularExpression(pattern: #"^\s*[-–•·]?\s*([^\s].*?)\s*도중\s*"#),
//            { m, s in
//                let rawName = (s as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
//                let name = stanceNameKRtoEN(rawName)
//                s.removeSubrange(Range(m.range, in: s)!)
//                // 문장 맨 앞은 대문자 "During", 컨텍스트가 이어붙여질 땐 앞에서 join으로 콤마 구분됨
//                return "During \(name)"
//            }
//        ))
        return arr
    }()

    // 3) 핵심 패턴 (본문 변환) — 순서 중요!
    static let corePatterns: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = {
        var arr: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = []

        // A) "히트 발동 시 X를 획득" → "Gain X on Heat activation"
        arr.append((
            try! NSRegularExpression(pattern: #"히트\s*발동\s*시\s*(.+?)를\s*획득"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Gain \(x) on Heat activation" }
        ))
        // B) "카운터 히트 시 X 상태로" → "Gain X on counter hit"
        arr.append((
            try! NSRegularExpression(pattern: #"카운터\s*히트\s*시\s*(.+?)\s*상태로"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Gain \(x) on counter hit" }
        ))
        // C) "히트 시 X 상태로" → "gain X on hit"
        arr.append((
            try! NSRegularExpression(pattern: #"히트\s*시\s*(.+?)\s*상태로"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "gain \(x) on hit" }
        ))
        // D) "히트 시 X으로" → "shift to X on hit"
        arr.append((
            try! NSRegularExpression(pattern: #"히트\s*시\s*(.+?)\s*으로"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "shift to \(x) on hit" }
        ))
        // D.1) "히트 or/혹은 가드 시" (뒤에 '상태로/으로'가 안 붙을 때만)
        arr.append((
            try! NSRegularExpression(pattern: #"(?<!\S)히트\s*(?:or|혹은)\s*가드\s*시(?!\s*(상태로|으로))"#),
            { _, _ in "on hit or block" }
        ))

        // D.2) "히트 시" (뒤에 '상태로/으로'가 안 붙을 때만)
        arr.append((
            try! NSRegularExpression(pattern: #"(?<!\S)히트\s*시(?!\s*(상태로|으로))"#),
            { _, _ in "on hit" }
        ))

        // D.3) "가드 시" (뒤에 '상태로/으로'가 안 붙을 때만)
        arr.append((
            try! NSRegularExpression(pattern: #"(?<!\S)가드\s*시(?!\s*(상태로|으로))"#),
            { _, _ in "on block" }
        ))
        // E) 히트 시 잡기로 -> "on hit shift to throw"
        arr.append((
            try! NSRegularExpression(pattern: #"히트\s*시\s*잡기\s*로"#),
            { _, _ in "on hit shift to throw" }
        ))
        // F) "X 를 획득" → "gain X"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)를\s*획득"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "gain \(x)" }
        ))
        // G) "X 입력 시 공격을 캔슬" → "X to cancel attack"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*공격(?:을)?\s*캔슬"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to cancel attack" }
        ))
        // X 입력 시 파워 상승 → X to power up
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*파워\s*상승"#),
            { m, s in
                let x = (s as NSString).substring(with: m.range(at: 1))
                return "\(x) to power up"
            }
        ))
        // H) "X 입력 시 캔슬" → "X to cancel"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*캔슬"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to cancel" }
        ))
        // I) "X 입력 시 Y으로" → "X to shift to Y"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*(.+?)으?로"#),
            { m, s in
                let x = (s as NSString).substring(with: m.range(at: 1))
                let y = (s as NSString).substring(with: m.range(at: 2))
                return "\(x) to shift to \(y)"
            }
        ))
        // I.5) 단독 전환: "X(으)로" → "Shift to X"
        //  - "입력 시 … 으로"(H)는 이미 위에서 처리
        //  - "…로 시작하는 공격으로 이어짐"(I)은 아래에서 처리되므로 충돌 회피를 위해 (?!\s*시작하는)
        arr.append((
            try! NSRegularExpression(pattern: #"([A-Za-z가-힣0-9][A-Za-z가-힣0-9 '’\-\./&]*?)\s*으?로(?!\s*시작하는)\b"#),
            { m, s in
                var name = (s as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                name = name.replacingOccurrences(of: #"^\s*입력\s*시\s*"#, with: "", options: .regularExpression)
                return "Shift to \(name)"
            }
        ))
        // I) "X 로 시작하는 공격으로 이어짐" → "Link to attack from X"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*로\s*시작하는\s*공격으로\s*이어짐"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Link to attack from \(x)" }
        ))
        // I.5) 단독 전환: "X(으)로" → "Shift to X"
        // ⚠️ H("입력 시 … 으로") / I("…로 시작하는 …") 뒤에 둬야 함.
        arr.append((
            try! NSRegularExpression(
                pattern: #"([A-Za-z가-힣0-9][A-Za-z가-힣0-9 '’\-\./&\(\)]*)\s*으?로(?!\s*시작하는)\b"#
            ),
            { m, s in
                var name = (s as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                // 혹시 앞에 "입력 시"가 섞여 들어온 경우 방지
                name = name.replacingOccurrences(of: #"^\s*입력\s*시\s*"#, with: "", options: .regularExpression)
                // 괄호 주변 공백 정리: "Left (Right)" → "Left(Right)"
                name = name
                    .replacingOccurrences(of: #"\s+\("#, with: "(", options: .regularExpression)
                    .replacingOccurrences(of: #"\)\s+"#, with: ")", options: .regularExpression)

                return "Shift to \(name)"
            }
        ))
        // J) "X 입력 시 직접 앉은 상태로" → "X to directly shift to crouching state"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*직접\s*앉은\s*상태로"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to directly shift to crouching state" }
        ))
        // K) "X 입력 시 쓰러진 상태로" → "X to downed"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*쓰러진\s*상태로"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to downed" }
        ))
        // L) "상대의 공격에 맞춰서 X" → "Time with opponent attack X"
        arr.append((
            try! NSRegularExpression(pattern: #"상대의\s*공격에\s*맞춰서\s*(.+)"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Time with opponent attack \(x)" }
        ))

        return arr
    }()

    // 4) 잔여 꼬리 패턴
    static let tailPatterns: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = {
        var arr: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = []
        // "X 도중에도 사용 가능" → "Also possible during X"
        arr.append((
            try! NSRegularExpression(pattern: #"(.+?)\s*도중에도\s*사용\s*가능"#),
            { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Also possible during \(x)" }
        ))
        arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*상태에?\s*서도\s*사용\s*가능"#),
                    { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Also possible during \(x)" }))
        return arr
    }()

    // 5) ‘혹은’ → or/Or 변환
    private static func replaceOrs(_ text: String) -> String {
        var result = text
        // 문장 맨앞: Or
        result = result.replacingOccurrences(of: #"^\s*혹은(\b|$)"#, with: "Or", options: .regularExpression)
        // 나머지: or
        result = result.replacingOccurrences(of: #"(\s)혹은(\s|$)"#, with: "$1or$2", options: .regularExpression)
        return result
    }

    // 6) 메인 변환 (문장 단위 전제 — 커맨드는 KRToENDescription에서 마스킹)
    static func translate(_ input: String) -> String {
        // (00) "X[, Y] 도중에도/상태에서도 사용 가능" → "Also possible during X[, Y]"
        let rx00 = try! NSRegularExpression(
            pattern: #"^\s*[-–•·]?\s*([^\n]+?)\s*(?:도중\s*에도|상태에?\s*서도)\s*사용\s*가능\s*[.!]?\s*$"#)
        if let m = rx00.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            let rawList = (input as NSString).substring(with: m.range(at: 1))
            let items = rawList.split(separator: ",").map { stanceNameKRtoEN($0.trimmingCharacters(in: .whitespaces)) }
            return "Also possible during \(items.joined(separator: ", "))"
        }

        // (00b) "During X[, Y] 에도/상태에서도 사용 가능" → "Also possible during X[, Y]"
        let rx00b = try! NSRegularExpression(
            pattern: #"^\s*[-–•·]?\s*during\s+([^\n]+?)\s*(?:(?:상태에?\s*서도)|에도)\s*사용\s*가능\s*[.!]?\s*$"#,
            options: [.caseInsensitive]
        )
        if let m = rx00b.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            let rawList = (input as NSString).substring(with: m.range(at: 1))
            let items = rawList.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            return "Also possible during \(items.joined(separator: ", "))"
        }
        
        var s = input
        // (0) 맨 앞 불릿 + "혹은" 선처리: prefix로 넘기기
        var prefixTokens: [String] = []
        if let m = try? NSRegularExpression(pattern: #"^\s*[-–•·]?\s*혹은\b\s*"#)
            .firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
            // 앞의 "혹은"을 제거하고 prefix에 "Or" 추가
            s.removeSubrange(Range(m.range, in: s)!)
            prefixTokens.append("Or")
        }
        // (a) 고정 치환
        for (pat, rep) in fixedDict {
            s = s.replacingOccurrences(of: pat, with: rep, options: .regularExpression)
        }

        // (b) 접두 컨텍스트 반복 추출
        var contexts: [String] = []
        var loop = true
        while loop {
            loop = false
            for (rx, handler) in leadingContexts {
                if let m = rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
                    let en = handler(m, &s)
                    contexts.append(en)
                    loop = true
                    break
                }
            }
        }
        
        if !contexts.isEmpty {
            let during = contexts.filter { $0.hasPrefix("During ") || $0.hasPrefix("during ") }
            let others = contexts.filter { !( $0.hasPrefix("During ") || $0.hasPrefix("during ") ) }
            if !during.isEmpty && others.isEmpty {
                // "During X" 들만 있다면 → "During A and B"
                let names = during.map { $0.replacingOccurrences(of: #"(?i)^during\s+"#, with: "", options: .regularExpression) }
                let merged = "During " + names.joined(separator: " and ")
                contexts = [merged]
            }
        }

        // (c) 핵심 패턴 반복 적용
        for (rx, handler) in corePatterns {
            while let m = rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
                let rep = handler(m, s)
                s = (s as NSString).replacingCharacters(in: m.range, with: rep)
            }
        }

        // (d) 꼬리 패턴
        for (rx, handler) in tailPatterns {
            while let m = rx.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) {
                let rep = handler(m, s)
                s = (s as NSString).replacingCharacters(in: m.range, with: rep)
            }
        }

        // (e) 혹은 → or / Or
        s = replaceOrs(s)

        // (f) 컨텍스트(prefix) 합치기
        let contextsPrefix = contexts.isEmpty ? "" : contexts.joined(separator: ", ")
        let prefixParts = (prefixTokens + (contextsPrefix.isEmpty ? [] : [contextsPrefix]))
        let prefix = prefixParts.isEmpty ? "" : prefixParts.joined(separator: ", ") + " "
        let result = (prefix + s)
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return result
    }
    
    private static func stanceNameKRtoEN(_ raw: String) -> String {
        // 공백/괄호 정리
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 대표 패턴(좌/우)
        // "왼쪽 횡이동" / "좌 횡이동" / "횡이동 좌" -> Sidestep left
        // "오른쪽 횡이동" / "우 횡이동" / "횡이동 우" -> Sidestep right
        let leftPatterns = [
            #"왼쪽\s*횡이동"#, #"좌\s*횡이동"#, #"횡이동\s*좌"#, #"왼쪽\s*횡보"#, #"좌\s*횡보"#, #"횡보\s*좌"#
        ]
        let rightPatterns = [
            #"오른쪽\s*횡이동"#, #"우\s*횡이동"#, #"횡이동\s*우"#, #"오른쪽\s*횡보"#, #"우\s*횡보"#, #"횡보\s*우"#
        ]
        for p in leftPatterns {
            if s.range(of: p, options: .regularExpression) != nil { return "Sidestep left" }
        }
        for p in rightPatterns {
            if s.range(of: p, options: .regularExpression) != nil { return "Sidestep right" }
        }

        // 단일 키워드 매핑 (필요시 계속 추가)
        let dict: [String: String] = [
            "횡이동": "Sidestep", "횡보": "Sidewalk",
            "반시계 방향 횡이동": "Sidestep left",
            "시계 방향 횡이동": "Sidestep right",
            // 이미 EN인 스탠스명은 그대로 반환되도록 아래에서 fallback
        ]
        if let hit = dict[s] { return hit }

        // 이미 영어거나 미지정 스탠스면 원문 반환
        return s
    }
}
