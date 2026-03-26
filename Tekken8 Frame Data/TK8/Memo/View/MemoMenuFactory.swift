//
//  MemoMenuFactory.swift
//  TK8
//

import Foundation
import UIKit

enum MemoMenuFactory {
    static func menu(isPinned: Bool, delete: @escaping () -> Void, togglePin: @escaping () -> Void) -> UIMenu {
        var items: [UIAction] {
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
            let items = [delete, togglePin]
            return items
        }
        let menu = UIMenu(children: items)
        return menu
    }
}
