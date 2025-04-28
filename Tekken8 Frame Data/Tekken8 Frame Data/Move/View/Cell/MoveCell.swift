//
//  MoveCell.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/8/25.
//

import SwiftUI

struct MoveCell: View, ReuseIdentifiable {
    let move: Move

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 기술명 + 커맨드
            HStack {
                Text(move.skillNameEN ?? "")
                    .font(.headline)
                Spacer()
                Text(move.command ?? "")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            // 판정 & 입력 이미지 (가능하면)
            HStack(spacing: 8) {
                Text(move.judgment ?? "")
                    .font(.caption)
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                
                // 👉 여기에 커맨드 입력 이미지 들어가면 최고
                CommandView(command: move.command ?? "")
//                Image("commandInputIcon") // Optional: 애셋 이름 또는 동적 뷰
            }

            // 데미지, 발동 등 주요 수치
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("💥 데미지")
                    Text(move.damage ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("⏱ 발동")
                    Text(move.startupFrame ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("🛡 가드")
                    Text(move.guardFrame ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("✅ 히트")
                    Text(move.hitFrame ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("⚡️ 카운터")
                    Text(move.counterFrame ?? "-")
                }
            }
            .font(.caption)

            // 추가 설명
            if let info = move.description, !info.isEmpty {
                Text("📌 \(info)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

struct CommandView: View {
    let command: String
    
    var body: some View {
        HStack {
            
        }
    }
    
    func parseCommand(_ input: String) -> [String] {
        
        return []
    }
}

#Preview {
    let move = Move(id: 1, characterName: "니나 윌리엄스", section: "히트", skillNameEN: "shake cancel", skillNameKR: "쉐캔", skillNickname: "쉐이크 캔슬", command: "6n23rp", judgment: "중", damage: "100", startupFrame: "15f", guardFrame: "+7", hitFrame: "+14", counterFrame: "+26", attribute: "", description: "개사기")
    MoveCell(move: move)
}
