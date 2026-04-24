//
//  PongTypes.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import CoreGraphics

// MARK: Model

nonisolated enum Side: Equatable { case left, right }

nonisolated enum PaddleInput: Equatable { case up, down, stop }

nonisolated struct Paddle: Equatable {
	var center: CGPoint
	var size: CGSize
	var verticalVelocity: CGFloat
}

nonisolated struct Ball: Equatable {
	var position: CGPoint
	var velocity: CGVector
	var radius: CGFloat
}

nonisolated struct PongModel: Equatable {
	var court: CGSize
	var ball: Ball
	var leftPaddle: Paddle
	var rightPaddle: Paddle
	var leftScore: Int
	var rightScore: Int
	var isPaused: Bool
	var hasStarted: Bool

	static let winningScore = 7

	static func initial(court: CGSize = .zero) -> PongModel {
		PongModel(
			court: court,
			ball: Self.makeBall(in: court, servingTo: .left),
			leftPaddle: Self.makePaddle(in: court, side: .left),
			rightPaddle: Self.makePaddle(in: court, side: .right),
			leftScore: 0,
			rightScore: 0,
			isPaused: true,
			hasStarted: false
		)
	}

	var winner: Side? {
		if leftScore >= Self.winningScore { return .left }
		if rightScore >= Self.winningScore { return .right }
		return nil
	}

	static func makeBall(in court: CGSize, servingTo side: Side) -> Ball {
		let speed: CGFloat = max(court.width, 1) * 0.45
		let dx: CGFloat = side == .left ? -speed : speed
		let dy: CGFloat = (Bool.random() ? 1 : -1) * speed * 0.5
		return Ball(
			position: CGPoint(x: court.width / 2, y: court.height / 2),
			velocity: CGVector(dx: dx, dy: dy),
			radius: 8
		)
	}

	static func makePaddle(in court: CGSize, side: Side) -> Paddle {
		let width: CGFloat = 12
		let height: CGFloat = max(court.height * 0.18, 60)
		let margin: CGFloat = 24
		let x: CGFloat = side == .left ? margin + width / 2 : court.width - margin - width / 2
		return Paddle(
			center: CGPoint(x: x, y: court.height / 2),
			size: CGSize(width: width, height: height),
			verticalVelocity: 0
		)
	}
}

// MARK: Event

nonisolated enum PongEvent: Equatable {
	case tick(dt: CGFloat)
	case playerInput(PaddleInput)
	case viewportChanged(CGSize)
	case reset
	case togglePause
}

// MARK: Effect

nonisolated enum PongEffect: Equatable {
	case hapticLight
	case hapticMedium
	case hapticSuccess
}
