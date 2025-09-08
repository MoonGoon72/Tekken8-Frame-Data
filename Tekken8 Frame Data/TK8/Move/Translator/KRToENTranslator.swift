//
//  KRToENTranslator.swift
//  TK8
//

import Foundation

struct KRToENTranslator {
    // 1) 고정 치환 (오탈자 포함 교정 가능)
    static let fixedDict: [(pattern: String, replace: String)] = [
        ("히트 상태의 남은 시간을 소비", "Partially uses remaining Heat time"),
        ("히트 상태 지속 중에는 파워 상승", "Power up during Heat"),
        ("효과 지속 중에는 가드할 수 없음", "Cannot block (attacks taken will count as counter hit)"),
        ("가드 데미지 있음", "Chip damage on block"),
        ("상대의 공격을 받아내면 파워 상승\\(가드 데미지 증가\\)", "Absorb an attack to power up (chip damage on block)"),
        ("펀치 흘리기 효과 있음", "Punch parry effect"),
        ("하단 흘리기 효과 있음", "Has low parry effect"),
        ("킥 흘리기 효과 있음", "Has kick parry effect"),
        ("방어 행동 관통 효과 있음", "Has reversal break effect"),
        ("빠르게 입력하면 파워 상승", "Power up with quick input"),
        ("홀드하면 파워 상승", "Hold at last step to power up"),
        // 단건 문장들
        ("정면 히트 시 잡기로", "Throw when hit from the front"),
        ("히트 시 상대의 회복 가능 게이지를 없앰", "Erases opponent’s recoverable health on hit"),
    ]
    // 2) 접두 컨텍스트(복수 가능) 추출 규칙
    //   - 앞에서부터 반복적으로 빼내며 누적: "히트 상태에서" + "몸을 숙인 상태에서" ...
    static let leadingContexts: [(NSRegularExpression, (NSTextCheckingResult, inout String) -> String)] = {
        var arr: [(NSRegularExpression, (NSTextCheckingResult, inout String) -> String)] = []

        // 히트 상태에서 → During Heat
        arr.append((try! NSRegularExpression(pattern: #"^\s*히트\s*상태에서\s*"#),
                    { m, s in
                        s.removeSubrange(Range(m.range, in: s)!)
                        return "During Heat"
                    }))
        // 레이지 상태에서 → During Rage
        arr.append((try! NSRegularExpression(pattern: #"^\s*레이지\s*상태에서\s*"#),
                    { m, s in
                        s.removeSubrange(Range(m.range, in: s)!)
                        return "During Rage"
                    }))
        // 몸을 숙인 상태에서 → While crouching
        arr.append((try! NSRegularExpression(pattern: #"^\s*몸을\s*숙인\s*상태에서\s*"#),
                    { m, s in
                        s.removeSubrange(Range(m.range, in: s)!)
                        return "While crouching"
                    }))
        // 일어나며 → While rising
        arr.append((try! NSRegularExpression(pattern: #"^\s*일어나며\s*"#),
                    { m, s in
                        s.removeSubrange(Range(m.range, in: s)!)
                        return "While rising"
                    }))
        // 상대에게 등을 보일 때 → Back facing opponent
        arr.append((try! NSRegularExpression(pattern: #"^\s*상대에게\s*등을\s*보일\s*때\s*"#),
                    { m, s in
                        s.removeSubrange(Range(m.range, in: s)!)
                        return "Back facing opponent"
                    }))
        // 상대 왼쪽/오른쪽/뒤에서 → Approach opponent from left/right/behind
        arr.append((try! NSRegularExpression(pattern: #"^\s*상대\s*왼쪽에서\s*"#),
                    { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Approach opponent from left side" }))
        arr.append((try! NSRegularExpression(pattern: #"^\s*상대\s*오른쪽에서\s*"#),
                    { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Approach opponent from right side" }))
        arr.append((try! NSRegularExpression(pattern: #"^\s*상대\s*뒤에서\s*"#),
                    { m, s in s.removeSubrange(Range(m.range, in: s)!); return "Approach opponent from behind" }))

        // 동적: "<임의문자> 도중" → "during <…>"
        arr.append((try! NSRegularExpression(pattern: #"^\s*([^\s].*?)\s*도중\s*"#),
                    { m, s in
                        let name = (s as NSString).substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
                        s.removeSubrange(Range(m.range, in: s)!)
                        return "during \(name)"
                    }))
        return arr
    }()
    // 3) 핵심 패턴 (본문 변환)
     static let corePatterns: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = {
         var arr: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = []

         // A) "히트 발동 시 X를 획득" → "Gain X on Heat activation"
         arr.append((try! NSRegularExpression(pattern: #"히트\s*발동\s*시\s*(.+?)를\s*획득"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Gain \(x) on Heat activation" }))

         // B) "카운터 히트 시 X 상태로" → "Gain X on counter hit"
         arr.append((try! NSRegularExpression(pattern: #"카운터\s*히트\s*시\s*(.+?)\s*상태로"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Gain \(x) on counter hit" }))

         // C) "히트 시 X 상태로" → "gain X on hit"
         arr.append((try! NSRegularExpression(pattern: #"히트\s*시\s*(.+?)\s*상태로"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "gain \(x) on hit" }))

         // D) "히트 시 X으로" → "shift to X on hit"
         arr.append((try! NSRegularExpression(pattern: #"히트\s*시\s*(.+?)\s*으로"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "shift to \(x) on hit" }))

         // E) "X 를 획득" → "gain X"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)를\s*획득"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "gain \(x)" }))

         // F) "X 입력 시 공격을 캔슬" → "X to cancel attack"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*공격을\s*캔슬"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to cancel attack" }))

         // G) "X 입력 시 캔슬" → "X to cancel"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*캔슬"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to cancel" }))

         // H) "X 입력 시 Y으로" → "X to shift to Y"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*(.+?)으로"#),
                     { m, s in
                         let x = (s as NSString).substring(with: m.range(at: 1))
                         let y = (s as NSString).substring(with: m.range(at: 2))
                         return "\(x) to shift to \(y)"
                     }))

         // I) "X 로 시작하는 공격으로 이어짐" → "Link to attack from X"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*로\s*시작하는\s*공격으로\s*이어짐"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Link to attack from \(x)" }))

         // J) "X 입력 시 직접 앉은 상태로" → "X to directly shift to crouching state"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*직접\s*앉은\s*상태로"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to directly shift to crouching state" }))

         // K) "X 입력 시 쓰러진 상태로" → "X to downed"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*입력\s*시\s*쓰러진\s*상태로"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "\(x) to downed" }))

         // L) "상대의 공격에 맞춰서 X" → "Time with opponent attack X"
         arr.append((try! NSRegularExpression(pattern: #"상대의\s*공격에\s*맞춰서\s*(.+)"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Time with opponent attack \(x)" }))

         // M) "상대 왼쪽/오른쪽/뒤에서 X" → 위 컨텍스트로 뺀 뒤 남은 X만 그대로
         // (앞에서 leadingContexts가 앞부분을 영어로 바꾸고 잘라냄)

         return arr
     }()

     // 4) 잔여 "… 도중에도 사용 가능" / "… 도중 …" 후처리
     static let tailPatterns: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = {
         var arr: [(NSRegularExpression, (NSTextCheckingResult, String) -> String)] = []

         // "X 도중에도 사용 가능" → "Also possible during X"
         arr.append((try! NSRegularExpression(pattern: #"(.+?)\s*도중에도\s*사용\s*가능"#),
                     { m, s in let x = (s as NSString).substring(with: m.range(at: 1)); return "Also possible during \(x)" }))

         // "… 도중 Y" (문장 끝쪽) → "during X Y" 는 앞의 leadingContexts에서 대부분 처리함.
         return arr
     }()

     // 5) ‘혹은’ → or/Or 변환
     private static func replaceOrs(_ text: String) -> String {
         // 앞/중간 모두 처리: 앞문장 시작의 혹은 → Or, 그 외 → or
         var result = text
         // 문장 맨앞: ^\s*혹은(\b|$)
         result = result.replacingOccurrences(of: #"^\s*혹은(\b|$)"#,
                                              with: "Or",
                                              options: .regularExpression)
         // 나머지: (\s)혹은(\s|$)
         result = result.replacingOccurrences(of: #"(\s)혹은(\s|$)"#,
                                              with: "$1or$2",
                                              options: .regularExpression)
         return result
     }

     // 6) 메인 변환
     static func translate(_ input: String) -> String {
         // (a) 고정 치환
         var s = input
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
         // 예: ["During Heat", "While crouching", "during Chaos Judgement"] + "rp"
         let prefix = contexts.isEmpty ? "" : contexts.joined(separator: ", ") + " "
         let result = (prefix + s).replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
         return result
     }
}
