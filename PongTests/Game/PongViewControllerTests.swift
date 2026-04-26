//
//  PongViewControllerTests.swift
//  PongTests
//

import UIKit
import XCTest
@testable import Pong

final class PongViewControllerTests: XCTestCase {

	func test_init_doesNotCrash() {
		_ = PongViewController()
	}

	func test_loadView_installsGameView() {
		// Arrange / Act
		let vc = PongViewController()
		_ = vc.view
		// Assert
		XCTAssertTrue(vc.view is PongGameView)
	}

	func test_viewDidLoad_setsDarkInterface() {
		// Arrange / Act
		let vc = PongViewController()
		_ = vc.view
		// Assert
		XCTAssertEqual(vc.overrideUserInterfaceStyle, .dark)
	}

	func test_appearLifecycle_startsAndStopsLoop() {
		// Arrange — paired appear / disappear keeps the Mobius loop running
		// only inside the test method body; stop() runs before the VC is
		// released so the internal queue tears down cleanly.
		let vc = PongViewController()
		_ = vc.view
		// Act
		vc.beginAppearanceTransition(true, animated: false)
		vc.endAppearanceTransition()
		vc.beginAppearanceTransition(false, animated: false)
		vc.endAppearanceTransition()
		// Assert — completed without crashing
		XCTAssertNotNil(vc.view)
	}
}
