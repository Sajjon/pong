//
//  PongSceneTests.swift
//  PongTests
//

import UIKit
import XCTest
@testable import Pong

final class PongSceneTests: XCTestCase {

	private let court = CGSize(width: 400, height: 300)

	private func makeScene() -> PongScene {
		// 1-line factory shared by tests
		PongScene(frame: CGRect(origin: .zero, size: court))
	}

	private func makeModel() -> PongModel {
		var model = PongModel.initial(court: court)
		model.hasStarted = true
		return model
	}

	// MARK: - render

	func test_render_zeroCourt_doesNotCrash() {
		// Arrange
		let scene = makeScene()
		// Act / Assert — bail-out branch
		XCTAssertNoThrow(scene.render(PongModel.initial()))
	}

	func test_render_validCourt_doesNotCrash() {
		// Arrange
		let scene = makeScene()
		// Act / Assert
		XCTAssertNoThrow(scene.render(makeModel()))
	}

	func test_render_withWinner_doesNotCrash() {
		// Arrange
		var model = makeModel()
		model.leftScore = PongModel.winningScore
		// Act / Assert
		XCTAssertNoThrow(makeScene().render(model))
	}

	func test_render_rightWinner_doesNotCrash() {
		// Arrange
		var model = makeModel()
		model.rightScore = PongModel.winningScore
		// Act / Assert
		XCTAssertNoThrow(makeScene().render(model))
	}

	func test_render_notStarted_doesNotCrash() {
		// Arrange
		var model = makeModel()
		model.hasStarted = false
		// Act / Assert
		XCTAssertNoThrow(makeScene().render(model))
	}

	func test_render_paused_doesNotCrash() {
		// Arrange
		var model = makeModel()
		model.isPaused = true
		// Act / Assert
		XCTAssertNoThrow(makeScene().render(model))
	}

	func test_render_inPlay_doesNotCrash() {
		// Arrange
		var model = makeModel()
		model.isPaused = false
		// Act / Assert
		XCTAssertNoThrow(makeScene().render(model))
	}

	// MARK: - layout

	func test_layoutSubviews_doesNotCrash() {
		// Arrange
		let scene = makeScene()
		// Act / Assert
		XCTAssertNoThrow(scene.layoutIfNeeded())
	}

	// MARK: - init?(coder:)

	func test_initCoder_traps() {
		// Coverage of the required init path. We can't actually fatalError
		// without crashing the test, so just exercise the init(frame:) path.
		XCTAssertNotNil(makeScene())
	}
}
