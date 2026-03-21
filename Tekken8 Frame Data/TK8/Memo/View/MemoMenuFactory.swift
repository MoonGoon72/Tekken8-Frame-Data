//
//  MemoMenuFactory.swift
//  TK8
//

import Foundation
import UIKit

enum MemoMenuFactory {
    static func menu(delete: @escaping () -> Void, share: @escaping () -> Void) -> UIMenu {
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
            let items = [delete, share]
            return items
        }
        let menu = UIMenu(children: items)
        return menu
    }
}
