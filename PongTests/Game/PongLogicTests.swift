//
//  PongLogicTests.swift
//  PongTests
//

import MobiusCore
import XCTest
@testable import Pong

final class PongLogicTests: XCTestCase {

	// Shared fixture: a court big enough that physics behaves predictably.
	private let court = CGSize(width: 400, height: 300)

	// MARK: - Helpers

	private func startedModel() -> PongModel {
		// Arrange helper for "the game has begun, ball is centered".
		var model = PongModel.initial(court: court)
		model.hasStarted = true
		model.isPaused = false
		return model
	}

	// MARK: - initiate

	func test_initiate_returnsModelUnchanged() {
		// Arrange
		let model = PongModel.initial(court: court)
		// Act
		let first = PongLogic.initiate(model)
		// Assert
		XCTAssertEqual(first.model, model)
	}

	func test_initiate_returnsNoEffects() {
		XCTAssertTrue(PongLogic.initiate(.initial()).effects.isEmpty)
	}

	// MARK: - update dispatch — verify each case routes (smoke per case)

	func test_update_tick_routesToOnTick() {
		// Arrange
		let model = startedModel()
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertNotNil(next.model)
	}

	func test_update_tap_routes() {
		XCTAssertNotNil(PongLogic.update(model: startedModel(), event: .tap).model)
	}

	func test_update_dragTo_routes() {
		XCTAssertNotNil(PongLogic.update(model: startedModel(), event: .dragTo(y: 0)).model)
	}

	func test_update_dragEnded_routes() {
		// Act
		let next = PongLogic.update(model: startedModel(), event: .dragEnded)
		// Assert
		XCTAssertEqual(next.model?.leftPaddle.verticalVelocity, 0)
	}

	func test_update_playerInput_routes() {
		XCTAssertNotNil(PongLogic.update(model: startedModel(), event: .playerInput(.up)).model)
	}

	func test_update_viewportChanged_routes() {
		// Act
		let next = PongLogic.update(model: PongModel.initial(), event: .viewportChanged(court))
		// Assert
		XCTAssertEqual(next.model?.court, court)
	}

	func test_update_reset_routes() {
		XCTAssertNotNil(PongLogic.update(model: startedModel(), event: .reset).model)
	}

	func test_update_togglePause_routes() {
		XCTAssertNotNil(PongLogic.update(model: startedModel(), event: .togglePause).model)
	}

	// MARK: - onTick guards

	func test_onTick_paused_returnsNoChange() {
		// Arrange
		var model = startedModel()
		model.isPaused = true
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertNil(next.model)
	}

	func test_onTick_winnerExists_returnsNoChange() {
		// Arrange
		var model = startedModel()
		model.leftScore = PongModel.winningScore
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertNil(next.model)
	}

	func test_onTick_zeroCourt_returnsNoChange() {
		// Arrange
		var model = PongModel.initial()
		model.hasStarted = true
		model.isPaused = false
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertNil(next.model)
	}

	// MARK: - onTick paddle motion

	func test_onTick_playerVelocityNonzero_paddleMoves() {
		// Arrange
		var model = startedModel()
		model.leftPaddle.verticalVelocity = 100
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertGreaterThan(next.model!.leftPaddle.center.y, model.leftPaddle.center.y)
	}

	func test_onTick_aiPaddleTracksBall() {
		// Arrange — ball above AI paddle, AI should move up
		var model = startedModel()
		model.ball.position.y = 10
		model.rightPaddle.center.y = 200
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertLessThan(next.model!.rightPaddle.center.y, 200)
	}

	// MARK: - onTick ball motion

	func test_onTick_ballMovesByVelocity() {
		// Arrange
		var model = startedModel()
		model.ball.position = CGPoint(x: 200, y: 150)
		model.ball.velocity = CGVector(dx: 100, dy: 0)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertEqual(next.model!.ball.position.x, 210, accuracy: 0.001)
	}

	// MARK: - onTick wall bounces

	func test_onTick_topWallCollision_bouncesDownAndEmitsHaptic() {
		// Arrange — ball stuck through top with upward velocity
		var model = startedModel()
		model.ball.position = CGPoint(x: 200, y: 5)
		model.ball.velocity = CGVector(dx: 0, dy: -100)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertGreaterThan(next.model!.ball.velocity.dy, 0)
		XCTAssertTrue(next.effects.contains(.hapticLight))
	}

	func test_onTick_bottomWallCollision_bouncesUpAndEmitsHaptic() {
		// Arrange
		var model = startedModel()
		model.ball.position = CGPoint(x: 200, y: court.height - 5)
		model.ball.velocity = CGVector(dx: 0, dy: 100)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertLessThan(next.model!.ball.velocity.dy, 0)
		XCTAssertTrue(next.effects.contains(.hapticLight))
	}

	// MARK: - onTick paddle reflections

	func test_onTick_ballHitsLeftPaddle_reflectsAndEmitsHaptic() {
		// Arrange
		var model = startedModel()
		model.ball.position = CGPoint(x: model.leftPaddle.center.x, y: model.leftPaddle.center.y)
		model.ball.velocity = CGVector(dx: -100, dy: 0)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertGreaterThan(next.model!.ball.velocity.dx, 0)
		XCTAssertTrue(next.effects.contains(.hapticMedium))
	}

	func test_onTick_ballHitsRightPaddle_reflectsAndEmitsHaptic() {
		// Arrange
		var model = startedModel()
		model.ball.position = CGPoint(x: model.rightPaddle.center.x, y: model.rightPaddle.center.y)
		model.ball.velocity = CGVector(dx: 100, dy: 0)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertLessThan(next.model!.ball.velocity.dx, 0)
		XCTAssertTrue(next.effects.contains(.hapticMedium))
	}

	// MARK: - onTick scoring

	func test_onTick_ballPastLeftEdge_rightScoresAndEmitsSuccess() {
		// Arrange
		var model = startedModel()
		model.ball.position = CGPoint(x: -100, y: 150)
		model.ball.velocity = .zero
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertEqual(next.model!.rightScore, 1)
		XCTAssertTrue(next.effects.contains(.hapticSuccess))
	}

	func test_onTick_ballPastRightEdge_leftScoresAndEmitsSuccess() {
		// Arrange
		var model = startedModel()
		model.ball.position = CGPoint(x: court.width + 100, y: 150)
		model.ball.velocity = .zero
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertEqual(next.model!.leftScore, 1)
		XCTAssertTrue(next.effects.contains(.hapticSuccess))
	}

	func test_onTick_winningScoreReached_pauses() {
		// Arrange — left needs only one more point
		var model = startedModel()
		model.leftScore = PongModel.winningScore - 1
		model.ball.position = CGPoint(x: court.width + 100, y: 150)
		model.ball.velocity = .zero
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert
		XCTAssertTrue(next.model!.isPaused)
	}

	// MARK: - onTap

	func test_onTap_noWinner_togglesPause() {
		// Arrange
		var model = startedModel()
		model.isPaused = false
		// Act
		let next = PongLogic.update(model: model, event: .tap)
		// Assert
		XCTAssertTrue(next.model!.isPaused)
	}

	func test_onTap_withWinner_resets() {
		// Arrange
		var model = startedModel()
		model.leftScore = PongModel.winningScore
		// Act
		let next = PongLogic.update(model: model, event: .tap)
		// Assert
		XCTAssertEqual(next.model!.leftScore, 0)
	}

	// MARK: - onDragTo

	func test_onDragTo_aboveThreshold_setsPaddleUp() {
		// Arrange
		let model = startedModel()
		// Act — drag well above the paddle's current Y
		let next = PongLogic.update(model: model, event: .dragTo(y: model.leftPaddle.center.y - 100))
		// Assert
		XCTAssertLessThan(next.model!.leftPaddle.verticalVelocity, 0)
	}

	func test_onDragTo_belowThreshold_setsPaddleDown() {
		// Arrange
		let model = startedModel()
		// Act
		let next = PongLogic.update(model: model, event: .dragTo(y: model.leftPaddle.center.y + 100))
		// Assert
		XCTAssertGreaterThan(next.model!.leftPaddle.verticalVelocity, 0)
	}

	func test_onDragTo_withinThreshold_stops() {
		// Arrange
		var model = startedModel()
		model.leftPaddle.verticalVelocity = 500
		// Act — drag right on top of paddle
		let next = PongLogic.update(model: model, event: .dragTo(y: model.leftPaddle.center.y))
		// Assert
		XCTAssertEqual(next.model!.leftPaddle.verticalVelocity, 0)
	}

	// MARK: - onPlayerInput

	func test_playerInput_up_setsNegativeVelocity() {
		// Act
		let next = PongLogic.update(model: startedModel(), event: .playerInput(.up))
		// Assert
		XCTAssertLessThan(next.model!.leftPaddle.verticalVelocity, 0)
	}

	func test_playerInput_down_setsPositiveVelocity() {
		// Act
		let next = PongLogic.update(model: startedModel(), event: .playerInput(.down))
		// Assert
		XCTAssertGreaterThan(next.model!.leftPaddle.verticalVelocity, 0)
	}

	func test_playerInput_stop_setsZeroVelocity() {
		// Arrange
		var model = startedModel()
		model.leftPaddle.verticalVelocity = 500
		// Act
		let next = PongLogic.update(model: model, event: .playerInput(.stop))
		// Assert
		XCTAssertEqual(next.model!.leftPaddle.verticalVelocity, 0)
	}

	// MARK: - onViewportChanged

	func test_viewportChanged_zeroSize_returnsNoChange() {
		// Act
		let next = PongLogic.update(model: startedModel(), event: .viewportChanged(.zero))
		// Assert
		XCTAssertNil(next.model)
	}

	func test_viewportChanged_notStarted_buildsFreshModel() {
		// Arrange
		let model = PongModel.initial()
		// Act
		let next = PongLogic.update(model: model, event: .viewportChanged(court))
		// Assert
		XCTAssertEqual(next.model!.court, court)
	}

	func test_viewportChanged_started_rescalesPositions() {
		// Arrange — start with 400x300, scale to 800x600 (×2)
		var model = startedModel()
		model.ball.position = CGPoint(x: 100, y: 100)
		// Act
		let next = PongLogic.update(model: model, event: .viewportChanged(.init(width: 800, height: 600)))
		// Assert
		XCTAssertEqual(next.model!.ball.position.x, 200, accuracy: 0.001)
	}

	// MARK: - onReset

	func test_reset_clearsScores() {
		// Arrange
		var model = startedModel()
		model.leftScore = 3
		model.rightScore = 4
		// Act
		let next = PongLogic.update(model: model, event: .reset)
		// Assert
		XCTAssertEqual(next.model!.leftScore, 0)
		XCTAssertEqual(next.model!.rightScore, 0)
	}

	func test_reset_isUnpaused() {
		XCTAssertFalse(PongLogic.update(model: startedModel(), event: .reset).model!.isPaused)
	}

	func test_reset_setsHasStarted() {
		XCTAssertTrue(PongLogic.update(model: startedModel(), event: .reset).model!.hasStarted)
	}

	// MARK: - onTogglePause

	func test_togglePause_unpausedToPaused() {
		// Arrange
		var model = startedModel()
		model.isPaused = false
		// Act
		let next = PongLogic.update(model: model, event: .togglePause)
		// Assert
		XCTAssertTrue(next.model!.isPaused)
	}

	func test_togglePause_pausedToUnpaused() {
		// Arrange
		var model = startedModel()
		model.isPaused = true
		// Act
		let next = PongLogic.update(model: model, event: .togglePause)
		// Assert
		XCTAssertFalse(next.model!.isPaused)
	}

	func test_togglePause_setsHasStarted() {
		// Arrange
		let model = PongModel.initial(court: court)
		// Act
		let next = PongLogic.update(model: model, event: .togglePause)
		// Assert
		XCTAssertTrue(next.model!.hasStarted)
	}

	func test_togglePause_withWinner_returnsNoChange() {
		// Arrange
		var model = startedModel()
		model.leftScore = PongModel.winningScore
		// Act
		let next = PongLogic.update(model: model, event: .togglePause)
		// Assert
		XCTAssertNil(next.model)
	}

	// MARK: - clamp behaviour (via tick)

	func test_onTick_paddleClampedAtTop() {
		// Arrange — paddle moving up beyond top edge
		var model = startedModel()
		model.leftPaddle.center.y = 0
		model.leftPaddle.verticalVelocity = -10000
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertEqual(next.model!.leftPaddle.center.y, model.leftPaddle.size.height / 2)
	}

	func test_onTick_paddleClampedAtBottom() {
		// Arrange
		var model = startedModel()
		model.leftPaddle.center.y = court.height
		model.leftPaddle.verticalVelocity = 10000
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.1))
		// Assert
		XCTAssertEqual(next.model!.leftPaddle.center.y, court.height - model.leftPaddle.size.height / 2)
	}

	// MARK: - reflect: anti-stick (moving away)

	func test_onTick_ballOverlapsPaddleButMovingAway_doesNotReflect() {
		// Arrange — ball already moving away from left paddle (rightward)
		var model = startedModel()
		model.ball.position = CGPoint(x: model.leftPaddle.center.x, y: model.leftPaddle.center.y)
		model.ball.velocity = CGVector(dx: 100, dy: 0)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert — velocity stays positive (no reflect)
		XCTAssertGreaterThan(next.model!.ball.velocity.dx, 0)
	}

	// MARK: - reflect: speed cap

	func test_onTick_paddleHitAtMaxSpeed_clampsToMaxSpeed() {
		// Arrange — ball already going at near-cap with steep angle
		var model = startedModel()
		model.ball.position = CGPoint(x: model.leftPaddle.center.x, y: model.leftPaddle.center.y - 20)
		model.ball.velocity = CGVector(dx: -1500, dy: -800)
		// Act
		let next = PongLogic.update(model: model, event: .tick(dt: 0.001))
		// Assert — total speed must not exceed max
		let v = next.model!.ball.velocity
		let speed = sqrt(v.dx * v.dx + v.dy * v.dy)
		XCTAssertLessThanOrEqual(speed, PongLogic.maxBallSpeed + 0.001)
	}
}
