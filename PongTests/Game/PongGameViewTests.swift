//
//  PongGameViewTests.swift
//  PongTests
//

import MobiusCore
import UIKit
import XCTest
@testable import Pong

final class PongGameViewTests: XCTestCase {

	private let frame = CGRect(x: 0, y: 0, width: 400, height: 300)

	// MARK: - init

	func test_init_doesNotCrash() {
		_ = PongGameView(frame: frame)
	}

	func test_init_isFirstResponderEligible() {
		XCTAssertTrue(PongGameView(frame: frame).canBecomeFirstResponder)
	}

	// MARK: - connect

	func test_connect_emitsViewportChangedIfSized() {
		// Arrange
		let view = PongGameView(frame: frame)
		var events: [PongEvent] = []
		// Act
		_ = view.connect { events.append($0) }
		// Assert
		XCTAssertTrue(events.contains(.viewportChanged(frame.size)))
	}

	func test_connect_zeroFrame_doesNotEmitViewportChanged() {
		// Arrange
		let view = PongGameView(frame: .zero)
		var events: [PongEvent] = []
		// Act
		_ = view.connect { events.append($0) }
		// Assert
		XCTAssertTrue(events.isEmpty)
	}

	func test_connect_acceptModel_doesNotCrash() {
		// Arrange
		let view = PongGameView(frame: frame)
		let connection = view.connect { _ in }
		// Act / Assert
		XCTAssertNoThrow(connection.accept(.initial(court: frame.size)))
	}

	func test_connect_dispose_doesNotCrash() {
		// Arrange
		let connection = PongGameView(frame: frame).connect { _ in }
		// Act / Assert
		XCTAssertNoThrow(connection.dispose())
	}

	// MARK: - layoutSubviews

	func test_layoutSubviews_emitsViewportChanged() {
		// Arrange
		let view = PongGameView(frame: frame)
		var events: [PongEvent] = []
		_ = view.connect { events.append($0) }
		events.removeAll()
		// Act
		view.setNeedsLayout()
		view.layoutIfNeeded()
		// Assert
		XCTAssertTrue(events.contains(.viewportChanged(frame.size)))
	}

	// MARK: - didMoveToWindow

	func test_didMoveToWindow_attached_becomesFirstResponder() {
		// Arrange
		let view = PongGameView(frame: frame)
		let window = UIWindow(frame: frame)
		// Act
		window.addSubview(view)
		// Assert
		XCTAssertTrue(view.isFirstResponder)
	}

	// MARK: - Gesture forwarding

	func test_tapGesture_dispatchesTap() {
		// Arrange
		let view = PongGameView(frame: frame)
		var events: [PongEvent] = []
		_ = view.connect { events.append($0) }
		// Act
		view.handleTap()
		// Assert
		XCTAssertTrue(events.contains(.tap))
	}

	func test_panGesture_changed_dispatchesDragTo() {
		// Arrange
		let (view, gesture) = panSetup()
		gesture.fakeState = .changed
		var events: [PongEvent] = []
		_ = view.connect { events.append($0) }
		events.removeAll()
		// Act
		view.handlePan(gesture)
		// Assert
		XCTAssertTrue(events.contains(where: { if case .dragTo = $0 { true } else { false } }))
	}

	func test_panGesture_began_dispatchesDragTo() {
		// Arrange
		let (view, gesture) = panSetup()
		gesture.fakeState = .began
		var events: [PongEvent] = []
		_ = view.connect { events.append($0) }
		events.removeAll()
		// Act
		view.handlePan(gesture)
		// Assert
		XCTAssertTrue(events.contains(where: { if case .dragTo = $0 { true } else { false } }))
	}

	func test_panGesture_ended_dispatchesDragEnded() {
		// Arrange
		let (view, gesture) = panSetup()
		gesture.fakeState = .ended
		var events: [PongEvent] = []
		_ = view.connect { events.append($0) }
		events.removeAll()
		// Act
		view.handlePan(gesture)
		// Assert
		XCTAssertTrue(events.contains(.dragEnded))
	}

	func test_panGesture_possible_dispatchesNothing() {
		// Arrange
		let (view, gesture) = panSetup()
		gesture.fakeState = .possible
		var events: [PongEvent] = []
		_ = view.connect { events.append($0) }
		events.removeAll()
		// Act
		view.handlePan(gesture)
		// Assert
		XCTAssertFalse(events.contains(.dragEnded))
	}

	private func panSetup() -> (PongGameView, FakePan) {
		let view = PongGameView(frame: frame)
		let gesture = FakePan()
		return (view, gesture)
	}

	// MARK: - Press forwarding (responder chain)

	func test_pressesBegan_emptySet_callsSuper() {
		// Arrange
		let view = PongGameView(frame: frame)
		// Act / Assert — empty press set is a no-op that should not crash
		XCTAssertNoThrow(view.pressesBegan([], with: nil))
	}

	func test_pressesEnded_emptySet_callsSuper() {
		XCTAssertNoThrow(PongGameView(frame: frame).pressesEnded([], with: nil))
	}

	func test_pressesCancelled_emptySet_callsSuper() {
		XCTAssertNoThrow(PongGameView(frame: frame).pressesCancelled([], with: nil))
	}
}

private final class FakePan: UIPanGestureRecognizer {
	var fakeState: UIPanGestureRecognizer.State = .possible
	override var state: UIPanGestureRecognizer.State {
		get { fakeState }
		set { fakeState = newValue }
	}
	override func location(in view: UIView?) -> CGPoint { .zero }
}
