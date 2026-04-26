//
//  SceneDelegateTests.swift
//  PongTests
//

import UIKit
import XCTest
@testable import Pong

final class SceneDelegateTests: XCTestCase {

	func test_init_doesNotCrash() {
		_ = SceneDelegate()
	}

	func test_window_initiallyNil() {
		XCTAssertNil(SceneDelegate().window)
	}
}
