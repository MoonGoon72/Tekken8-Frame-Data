//
//  AppDelegate.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 1/21/25.
//

import Firebase
import FirebaseAnalytics
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            #if DEBUG
            let isDebugBuild = true
            #else
            let isDebugBuild = false
            #endif

            if TK8AnalyticsCollectionPolicy.shouldCollect(
                isDebugBuild: isDebugBuild,
                launchArguments: ProcessInfo.processInfo.arguments
            ) {
                FirebaseApp.configure()
                Analytics.setAnalyticsCollectionEnabled(true)
            }
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
