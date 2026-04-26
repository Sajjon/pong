//
//  KeyboardInputMapperTests.swift
//  PongTests
//

import UIKit
import XCTest
@testable import Pong

// MARK: Test fakes

private final class FakeKey: UIKey {
	private let _keyCode: UIKeyboardHIDUsage
	init(_ code: UIKeyboardHIDUsage) {
		_keyCode = code
		super.init()
	}
	required init?(coder: NSCoder) { fatalError() }
	override var keyCode: UIKeyboardHIDUsage { _keyCode }
}

private final class FakePress: UIPress {
	private let _key: UIKey?
	init(_ key: UIKey?) {
		_key = key
		super.init()
	}
	override var key: UIKey? { _key }
}

private func press(_ code: UIKeyboardHIDUsage) -> Set<UIPress> {
	[FakePress(FakeKey(code))]
}

private func emptyPress() -> Set<UIPress> {
	[FakePress(nil)]
}

// MARK: Tests

final class KeyboardInputMapperTests: XCTestCase {

	private func capture() -> (KeyboardInputMapper, () -> [PongEvent]) {
		// Arrange helper — returns mapper + closure to read captured events
		var captured: [PongEvent] = []
		let mapper = KeyboardInputMapper { captured.append($0) }
		return (mapper, { captured })
	}

	// MARK: - pressesBegan

	func test_pressesBegan_upArrow_dispatchesUp() {
		// Arrange
		let (mapper, events) = capture()
		// Act
		mapper.pressesBegan(press(.keyboardUpArrow))
		// Assert
		XCTAssertEqual(events(), [.playerInput(.up)])
	}

	func test_pressesBegan_W_dispatchesUp() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardW))
		XCTAssertEqual(events(), [.playerInput(.up)])
	}

	func test_pressesBegan_downArrow_dispatchesDown() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardDownArrow))
		XCTAssertEqual(events(), [.playerInput(.down)])
	}

	func test_pressesBegan_S_dispatchesDown() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardS))
		XCTAssertEqual(events(), [.playerInput(.down)])
	}

	func test_pressesBegan_space_dispatchesTogglePause() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardSpacebar))
		XCTAssertEqual(events(), [.togglePause])
	}

	func test_pressesBegan_return_dispatchesTogglePause() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardReturnOrEnter))
		XCTAssertEqual(events(), [.togglePause])
	}

	func test_pressesBegan_R_dispatchesReset() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardR))
		XCTAssertEqual(events(), [.reset])
	}

	func test_pressesBegan_otherKey_returnsFalse() {
		// Act
		let handled = capture().0.pressesBegan(press(.keyboardA))
		// Assert
		XCTAssertFalse(handled)
	}

	func test_pressesBegan_pressWithoutKey_returnsFalse() {
		XCTAssertFalse(capture().0.pressesBegan(emptyPress()))
	}

	func test_pressesBegan_gameKey_returnsTrue() {
		XCTAssertTrue(capture().0.pressesBegan(press(.keyboardW)))
	}

	// MARK: - pressesEnded

	func test_pressesEnded_releaseUp_noOtherHeld_dispatchesStop() {
		// Arrange
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardUpArrow))
		// Act
		mapper.pressesEnded(press(.keyboardUpArrow))
		// Assert
		XCTAssertEqual(events().last, .playerInput(.stop))
	}

	func test_pressesEnded_releaseUp_WStillHeld_dispatchesUp() {
		// Arrange
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardUpArrow))
		mapper.pressesBegan(press(.keyboardW))
		// Act
		mapper.pressesEnded(press(.keyboardUpArrow))
		// Assert
		XCTAssertEqual(events().last, .playerInput(.up))
	}

	func test_pressesEnded_releaseUp_downStillHeld_dispatchesDown() {
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardUpArrow))
		mapper.pressesBegan(press(.keyboardDownArrow))
		mapper.pressesEnded(press(.keyboardUpArrow))
		XCTAssertEqual(events().last, .playerInput(.down))
	}

	func test_pressesEnded_otherKey_returnsFalse() {
		XCTAssertFalse(capture().0.pressesEnded(press(.keyboardA)))
	}

	func test_pressesEnded_pressWithoutKey_returnsFalse() {
		XCTAssertFalse(capture().0.pressesEnded(emptyPress()))
	}

	func test_pressesEnded_gameKey_returnsTrue() {
		// Arrange
		let mapper = capture().0
		mapper.pressesBegan(press(.keyboardW))
		// Act / Assert
		XCTAssertTrue(mapper.pressesEnded(press(.keyboardW)))
	}

	// MARK: - pressesCancelled

	func test_pressesCancelled_dispatchesStop() {
		// Arrange
		let (mapper, events) = capture()
		mapper.pressesBegan(press(.keyboardUpArrow))
		// Act
		mapper.pressesCancelled()
		// Assert
		XCTAssertEqual(events().last, .playerInput(.stop))
	}
}
