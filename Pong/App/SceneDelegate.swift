//
//  SceneDelegate.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  Per-window startup. iOS calls `scene(_:willConnectTo:options:)` once,
//  when the window first appears. This is where we:
//
//    1. Create a `UIWindow` for the scene.
//    2. Install our root view controller (`PongViewController`).
//    3. Make the window visible.
//
//  After that, all per-window lifecycle hooks (foreground/background)
//  would also be implemented here, but Pong doesn't need any.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	/// Strong reference to the scene's window. UIKit doesn't retain
	/// this for us — if we don't hold it, it gets deallocated and the
	/// screen goes blank.
	var window: UIWindow?

	/// Called once per scene, when iOS attaches it to a `UIWindowScene`.
	///
	/// - Parameters:
	///   - scene: Should be a `UIWindowScene` for visible windows; the
	///     `as?` cast guards against future scene types (e.g. headless).
	///   - session: Identifies which scene configuration this is —
	///     ignored here.
	///   - connectionOptions: Carries deep-link URLs, shortcut actions,
	///     etc. — ignored here.
	func scene(
		_ scene: UIScene,
		willConnectTo session: UISceneSession,
		options connectionOptions: UIScene.ConnectionOptions
	) {
		guard let windowScene = (scene as? UIWindowScene) else { return }

		// Create a window the size of the scene, install our root
		// view controller, and make it the key window so it receives
		// events.
		let window = UIWindow(windowScene: windowScene)
		window.rootViewController = PongViewController()
		window.makeKeyAndVisible()
		self.window = window
	}
}
