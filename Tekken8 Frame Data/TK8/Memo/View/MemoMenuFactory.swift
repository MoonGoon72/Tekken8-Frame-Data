//
//  MemoMenuFactory.swift
//  TK8
//

import Foundation
import UIKit

enum MemoMenuFactory {
    static func menu(isPinned: Bool, delete: @escaping () -> Void, share: @escaping () -> Void, togglePin: @escaping () -> Void) -> UIMenu {
        var items: [UIAction] {
            // TODO: 핀 토글기능
            let share = UIAction(
                title: "공유".localized(),
                image: UIImage(systemName: "paperplane")) { _ in
                    share()
                }
            let delete = UIAction(
                title: "삭제".localized(),
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                    delete()
                }
            let togglePin = UIAction(
                title: isPinned ? "고정 해제".localized() : "고정".localized(),
                image: UIImage(systemName: isPinned ? "pin.slash.fill" : "pin.fill"),
            ) { _ in
                togglePin()
            }
            let items = [delete, share, togglePin]
            return items
        }
        let menu = UIMenu(children: items)
        return menu
    }
}
