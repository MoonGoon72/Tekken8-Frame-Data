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
    private let versionManager: FrameDataVersionManageable
    
    override init() {
        versionManager = container.makeFrameDataVersionManager()
        
        super.init()
    }
     
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        
        Task {
            do {
                try await versionManager.checkVersion()
            } catch {
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
