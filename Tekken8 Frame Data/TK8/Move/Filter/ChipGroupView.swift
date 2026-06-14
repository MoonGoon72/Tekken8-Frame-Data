//
//  ChipGroupView.swift
//  TK8
//

import SwiftUI

// MARK: - ChipItem

enum ChipItem: Hashable {
    case text(text: String)
    case icon(text: String)

    var value: String {
        switch self {
        case .text(let text):
            return text
        case .icon(let text):
            return text
        }
    }
}

struct ChipGroupView: View {
    var body: some View {
        
    }
}

#Preview {
//    ChipGroupView()
}
