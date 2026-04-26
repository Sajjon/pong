//
//  PongEffectHandlerTests.swift
//  PongTests
//

import MobiusCore
import XCTest
@testable import Pong

final class PongEffectHandlerTests: XCTestCase {

	func test_init_doesNotCrash() {
		_ = PongEffectHandler()
	}

	func test_connect_returnsConnection() {
		// Arrange
		let handler = PongEffectHandler()
		// Act
		let connection = handler.connect { _ in }
		// Assert
		XCTAssertNotNil(connection)
	}

	func test_accept_hapticLight_doesNotCrash() {
		// Arrange
		let connection = PongEffectHandler().connect { _ in }
		// Act / Assert — accept must run without throwing
		XCTAssertNoThrow(connection.accept(.hapticLight))
	}

	func test_accept_hapticMedium_doesNotCrash() {
		let connection = PongEffectHandler().connect { _ in }
		XCTAssertNoThrow(connection.accept(.hapticMedium))
	}

	func test_accept_hapticSuccess_doesNotCrash() {
		let connection = PongEffectHandler().connect { _ in }
		XCTAssertNoThrow(connection.accept(.hapticSuccess))
	}

	func test_dispose_doesNotCrash() {
		// Arrange
		let connection = PongEffectHandler().connect { _ in }
		// Act / Assert
		XCTAssertNoThrow(connection.dispose())
	}
}
