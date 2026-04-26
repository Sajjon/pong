//
//  PongEffectTests.swift
//  PongTests
//

import XCTest
@testable import Pong

final class PongEffectTests: XCTestCase {

	func test_hapticLight_equalsItself() {
		XCTAssertEqual(PongEffect.hapticLight, .hapticLight)
	}

	func test_hapticMedium_equalsItself() {
		XCTAssertEqual(PongEffect.hapticMedium, .hapticMedium)
	}

	func test_hapticSuccess_equalsItself() {
		XCTAssertEqual(PongEffect.hapticSuccess, .hapticSuccess)
	}

	func test_hapticLight_doesNotEqualMedium() {
		XCTAssertNotEqual(PongEffect.hapticLight, .hapticMedium)
	}

	func test_hapticMedium_doesNotEqualSuccess() {
		XCTAssertNotEqual(PongEffect.hapticMedium, .hapticSuccess)
	}
}
