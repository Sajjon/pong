//
//  AppDelegate.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The app's application-level entry point. iOS apps have two delegate
//  layers:
//
//    • UIApplicationDelegate — one per app, handles process-level events
//      (launch, low memory, push notifications…).
//    • UIWindowSceneDelegate — one per visible window, handles per-scene
//      lifecycle (foreground/background, configure root VC). See
//      SceneDelegate.swift.
//
//  In modern UIKit (iOS 13+), almost everything UI-related lives in the
//  scene delegate. This file just declares the app exists and tells iOS
//  which scene delegate class to use.
//

import UIKit

/// `@main` is the Swift attribute that marks a type as the program entry
/// point. UIKit's `@UIApplicationMain` macro (now `@main`) generates the
/// `main()` function that boots `UIApplication` with this class as the
/// app delegate.
@main
class AppDelegate: UIResponder {}

// MARK: - UIApplicationDelegate
extension AppDelegate: UIApplicationDelegate {

	/// Called by UIKit when the app needs a fresh scene configuration —
	/// typically when the user opens a new window. We hand back a
	/// `UISceneConfiguration` whose name matches the one in Info.plist
	/// under `UIApplicationSceneManifest`. iOS then instantiates our
	/// `SceneDelegate` to drive the new scene.
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
