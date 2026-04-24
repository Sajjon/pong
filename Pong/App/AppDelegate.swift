//
//  AppDelegate.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import UIKit

@main
class AppDelegate: UIResponder {}

// MARK: UIApplicationDelegate
extension AppDelegate: UIApplicationDelegate {
	func application(
		_ application: UIApplication,
		configurationForConnecting connectingSceneSession: UISceneSession,
		options: UIScene.ConnectionOptions
	) -> UISceneConfiguration {
		UISceneConfiguration(
			name: "Default Configuration",
			sessionRole: connectingSceneSession.role
		)
	}
}

