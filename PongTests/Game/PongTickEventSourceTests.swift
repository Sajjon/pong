//
//  PongTickEventSourceTests.swift
//  PongTests
//

import MobiusCore
import XCTest
@testable import Pong

final class PongTickEventSourceTests: XCTestCase {

	// MARK: - subscribe / dispose

	func test_subscribe_returnsDisposable() {
		// Arrange
		let source = PongTickEventSource()
		// Act
		let disposable = source.subscribe { _ in }
		// Assert
		XCTAssertNotNil(disposable)
		disposable.dispose()
	}

	func test_dispose_doesNotCrash() {
		// Arrange
		let disposable = PongTickEventSource().subscribe { _ in }
		// Act / Assert
		XCTAssertNoThrow(disposable.dispose())
	}

	// MARK: - tick(at:) — testable core

	func test_firstTick_doesNotEmit() {
		// Arrange
		let source = PongTickEventSource()
		var emitted: [PongEvent] = []
		_ = source.subscribe { emitted.append($0) }
		// Act
		source.tick(at: 100)
		// Assert
		XCTAssertTrue(emitted.isEmpty)
	}

	func test_secondTick_emitsTickWithDelta() {
		// Arrange
		let source = PongTickEventSource()
		var emitted: [PongEvent] = []
		_ = source.subscribe { emitted.append($0) }
		// Act — first call sets baseline, second emits
		source.tick(at: 100)
		source.tick(at: 100.016)
		// Assert
		XCTAssertEqual(emitted.count, 1)
	}

	func test_secondTick_dtIsCappedAtThirty() {
		// Arrange — second tick is 5 seconds later (way past the 1/30 cap)
		let source = PongTickEventSource()
		var emitted: [PongEvent] = []
		_ = source.subscribe { emitted.append($0) }
		source.tick(at: 100)
		// Act
		source.tick(at: 105)
		// Assert
		XCTAssertEqual(emitted, [.tick(dt: CGFloat(1.0 / 30.0))])
	}
}
