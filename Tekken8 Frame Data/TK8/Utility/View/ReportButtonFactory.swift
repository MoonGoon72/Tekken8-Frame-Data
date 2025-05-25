//
//  ReportButtonFactory.swift
//  TK8
//
//  Created by 문영균 on 5/1/25.
//

import UIKit

final class ReportButtonFactory {
    static func make(target: Any?, action: Selector) -> UIBarButtonItem {
        return UIBarButtonItem(
            image: UIImage(systemName: "envelope"),
            style: .plain,
            target: target,
            action: action
        )
    }
    
    @objc static func sendBugReport() {
        let to = "moongoon.cnu@gmail.com"
        let subject = "[버그 제보] TK8 앱 문제".localized()
        let body = """
            안녕하세요, 아래에 버그 내용을 적어주세요.
            Hello, please write down the bug below.
            
            --------------------
            App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "알 수 없음")
            iOS version: \(UIDevice.current.systemVersion)
            Device: \(UIDevice.current.model)
            --------------------
            """
        
        let email = "mailto:\(to)?subject=\(subject)&body=\(body)"
        if let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
