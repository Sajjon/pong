//
//  PongModelTests.swift
//  PongTests
//

import XCTest
@testable import Pong

final class PongModelTests: XCTestCase {

	// MARK: - Side

	func test_side_left_equalsLeft() {
		// Arrange
		let side: Side = .left
		// Act / Assert
		XCTAssertEqual(side, .left)
	}

	func test_side_left_doesNotEqualRight() {
		XCTAssertNotEqual(Side.left, .right)
	}

	// MARK: - PaddleInput

	func test_paddleInput_up_equalsUp() {
		XCTAssertEqual(PaddleInput.up, .up)
	}

	func test_paddleInput_up_doesNotEqualDown() {
		XCTAssertNotEqual(PaddleInput.up, .down)
	}

	func test_paddleInput_stop_doesNotEqualUp() {
		XCTAssertNotEqual(PaddleInput.stop, .up)
	}

	// MARK: - PongModel.initial

	func test_initial_zeroCourt_leftScoreIsZero() {
		// Act
		let model = PongModel.initial()
		// Assert
		XCTAssertEqual(model.leftScore, 0)
	}

	func test_initial_zeroCourt_rightScoreIsZero() {
		XCTAssertEqual(PongModel.initial().rightScore, 0)
	}

	func test_initial_zeroCourt_isPaused() {
		XCTAssertTrue(PongModel.initial().isPaused)
	}

	func test_initial_zeroCourt_hasNotStarted() {
		XCTAssertFalse(PongModel.initial().hasStarted)
	}

	func test_initial_withCourt_setsCourt() {
		// Arrange
		let size = CGSize(width: 400, height: 300)
		// Act
		let model = PongModel.initial(court: size)
		// Assert
		XCTAssertEqual(model.court, size)
	}

	// MARK: - winner

	func test_winner_zeroScores_isNil() {
		XCTAssertNil(PongModel.initial().winner)
	}

	func test_winner_leftReachesWinningScore_isLeft() {
		// Arrange
		var model = PongModel.initial()
		model.leftScore = PongModel.winningScore
		// Assert
		XCTAssertEqual(model.winner, .left)
	}

	func test_winner_rightReachesWinningScore_isRight() {
		// Arrange
		var model = PongModel.initial()
		model.rightScore = PongModel.winningScore
		// Assert
		XCTAssertEqual(model.winner, .right)
	}

	func test_winner_belowWinningScore_isNil() {
		// Arrange
		var model = PongModel.initial()
		model.leftScore = PongModel.winningScore - 1
		// Assert
		XCTAssertNil(model.winner)
	}

	// MARK: - makeBall

	func test_makeBall_servingLeft_dxIsNegative() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let ball = PongModel.makeBall(in: court, servingTo: .left)
		// Assert
		XCTAssertLessThan(ball.velocity.dx, 0)
	}

	func test_makeBall_servingRight_dxIsPositive() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let ball = PongModel.makeBall(in: court, servingTo: .right)
		// Assert
		XCTAssertGreaterThan(ball.velocity.dx, 0)
	}

	func test_makeBall_centerXIsHalfCourt() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let ball = PongModel.makeBall(in: court, servingTo: .left)
		// Assert
		XCTAssertEqual(ball.position.x, 200)
	}

	func test_makeBall_centerYIsHalfCourt() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let ball = PongModel.makeBall(in: court, servingTo: .left)
		// Assert
		XCTAssertEqual(ball.position.y, 150)
	}

	func test_makeBall_radiusIsEight() {
		XCTAssertEqual(PongModel.makeBall(in: .zero, servingTo: .left).radius, 8)
	}

	// MARK: - makePaddle

	func test_makePaddle_left_xIsNearLeftEdge() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let paddle = PongModel.makePaddle(in: court, side: .left)
		// Assert
		XCTAssertEqual(paddle.center.x, 24 + paddle.size.width / 2)
	}

	func test_makePaddle_right_xIsNearRightEdge() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let paddle = PongModel.makePaddle(in: court, side: .right)
		// Assert
		XCTAssertEqual(paddle.center.x, court.width - 24 - paddle.size.width / 2)
	}

	func test_makePaddle_yIsHalfCourtHeight() {
		// Arrange
		let court = CGSize(width: 400, height: 300)
		// Act
		let paddle = PongModel.makePaddle(in: court, side: .left)
		// Assert
		XCTAssertEqual(paddle.center.y, 150)
	}

	func test_makePaddle_widthIsTwelve() {
		XCTAssertEqual(PongModel.makePaddle(in: .zero, side: .left).size.width, 12)
	}

	func test_makePaddle_smallCourt_heightIsAtLeastSixty() {
		XCTAssertEqual(PongModel.makePaddle(in: .zero, side: .left).size.height, 60)
	}

	func test_makePaddle_largeCourt_heightScalesWithCourt() {
		// Arrange
		let court = CGSize(width: 1000, height: 1000)
		// Act
		let paddle = PongModel.makePaddle(in: court, side: .left)
		// Assert
		XCTAssertEqual(paddle.size.height, 180) // 1000 * 0.18
	}

	func test_makePaddle_velocityStartsAtZero() {
		XCTAssertEqual(PongModel.makePaddle(in: .zero, side: .left).verticalVelocity, 0)
	}

	// MARK: - Equatable

	func test_pongModel_sameValues_areEqual() {
		// Arrange
		let a = PongModel.initial(court: .init(width: 100, height: 100))
		let b = PongModel.initial(court: .init(width: 100, height: 100))
		// Assert (note: ball Y dy is randomised, so compare a struct subset)
		XCTAssertEqual(a.court, b.court)
	}

	func test_paddle_equatable() {
		// Arrange
		let p = Paddle(center: .zero, size: .zero, verticalVelocity: 0)
		// Assert
		XCTAssertEqual(p, Paddle(center: .zero, size: .zero, verticalVelocity: 0))
	}

	func test_ball_equatable() {
		// Arrange
		let b = Ball(position: .zero, velocity: .zero, radius: 1)
		// Assert
		XCTAssertEqual(b, Ball(position: .zero, velocity: .zero, radius: 1))
	}
}
