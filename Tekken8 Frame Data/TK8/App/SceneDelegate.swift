//
//  SceneDelegate.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 1/21/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let container = DIContainer()
    private let versionManager: VersionManageable
    
    override init() {
        versionManager = container.makeVersionManager()
        
        super.init()
    }
     
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        
        Task {
            do {
                try await versionManager.checkFrameDataVersion()
                try await versionManager.checkTekkenVersion()
            } catch {
                // TODO: 패치 실패하면 그냥 로컬에 있는거 보여주게 하면 될 것 같음. 지금은 패치 못하면 앱이 죽음
                NSLog(error.localizedDescription)
            }
        }
        
        let rootViewController = UINavigationController(rootViewController: container.makeCharacterListViewController())
        let viewController = rootViewController
        window.rootViewController = viewController
        
        self.window = window
        window.makeKeyAndVisible()
    }
}
