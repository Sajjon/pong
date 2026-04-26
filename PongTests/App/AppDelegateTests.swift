//
//  AppDelegateTests.swift
//  PongTests
//

import UIKit
import XCTest
@testable import Pong

final class AppDelegateTests: XCTestCase {

	func test_init_doesNotCrash() {
		_ = AppDelegate()
	}

	func test_isUIApplicationDelegate() {
		// AppDelegate must conform to UIApplicationDelegate (verified at compile time
		// via the protocol cast).
		XCTAssertNotNil(AppDelegate() as UIApplicationDelegate)
	}
}
