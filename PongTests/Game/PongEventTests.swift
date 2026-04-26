//
//  PongEventTests.swift
//  PongTests
//

import XCTest
@testable import Pong

final class PongEventTests: XCTestCase {

	func test_tick_equalsItself() {
		XCTAssertEqual(PongEvent.tick(dt: 0.5), .tick(dt: 0.5))
	}

	func test_tick_differentDt_notEqual() {
		XCTAssertNotEqual(PongEvent.tick(dt: 0.5), .tick(dt: 0.4))
	}

	func test_tap_equalsItself() {
		XCTAssertEqual(PongEvent.tap, .tap)
	}

	func test_dragTo_equalsSameY() {
		XCTAssertEqual(PongEvent.dragTo(y: 50), .dragTo(y: 50))
	}

	func test_dragTo_differentY_notEqual() {
		XCTAssertNotEqual(PongEvent.dragTo(y: 50), .dragTo(y: 60))
	}

	func test_dragEnded_equalsItself() {
		XCTAssertEqual(PongEvent.dragEnded, .dragEnded)
	}

	func test_playerInput_equatable() {
		XCTAssertEqual(PongEvent.playerInput(.up), .playerInput(.up))
	}

	func test_playerInput_differentInputs_notEqual() {
		XCTAssertNotEqual(PongEvent.playerInput(.up), .playerInput(.down))
	}

	func test_viewportChanged_equatable() {
		XCTAssertEqual(PongEvent.viewportChanged(.zero), .viewportChanged(.zero))
	}

	func test_reset_equalsItself() {
		XCTAssertEqual(PongEvent.reset, .reset)
	}

	func test_togglePause_equalsItself() {
		XCTAssertEqual(PongEvent.togglePause, .togglePause)
	}

	func test_tap_doesNotEqualReset() {
		XCTAssertNotEqual(PongEvent.tap, .reset)
	}
}
