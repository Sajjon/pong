//
//  PongLogic.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import CoreGraphics
import MobiusCore

nonisolated enum PongLogic {

	// MARK: Tuning

	static let playerPaddleSpeed: CGFloat = 520
	static let aiPaddleMaxSpeed: CGFloat = 380
	static let aiReactionGain: CGFloat = 6
	static let ballSpeedupOnPaddleHit: CGFloat = 1.06
	static let maxBallSpeed: CGFloat = 1400

	// MARK: Initiate

	static func initiate(_ model: PongModel) -> First<PongModel, PongEffect> {
		First(model: model)
	}

	// MARK: Update

	static func update(model: PongModel, event: PongEvent) -> Next<PongModel, PongEffect> {
		switch event {
		case .tick(let dt):
			return onTick(model, dt: dt)
		case .playerInput(let input):
			return onPlayerInput(model, input: input)
		case .viewportChanged(let size):
			return onViewportChanged(model, size: size)
		case .reset:
			return onReset(model)
		case .togglePause:
			return onTogglePause(model)
		}
	}

	// MARK: Event handlers

	private static func onTick(_ model: PongModel, dt: CGFloat) -> Next<PongModel, PongEffect> {
		guard !model.isPaused, model.winner == nil, model.court.width > 0 else {
			return .noChange
		}
		var m = model
		var effects: [PongEffect] = []

		m.leftPaddle.center.y = clampPaddleY(
			m.leftPaddle.center.y + m.leftPaddle.verticalVelocity * dt,
			paddle: m.leftPaddle,
			court: m.court
		)

		let deltaY = m.ball.position.y - m.rightPaddle.center.y
		let desired = max(-aiPaddleMaxSpeed, min(aiPaddleMaxSpeed, deltaY * aiReactionGain))
		m.rightPaddle.verticalVelocity = desired
		m.rightPaddle.center.y = clampPaddleY(
			m.rightPaddle.center.y + m.rightPaddle.verticalVelocity * dt,
			paddle: m.rightPaddle,
			court: m.court
		)

		m.ball.position.x += m.ball.velocity.dx * dt
		m.ball.position.y += m.ball.velocity.dy * dt

		if m.ball.position.y - m.ball.radius <= 0 {
			m.ball.position.y = m.ball.radius
			m.ball.velocity.dy = abs(m.ball.velocity.dy)
			effects.append(.hapticLight)
		} else if m.ball.position.y + m.ball.radius >= m.court.height {
			m.ball.position.y = m.court.height - m.ball.radius
			m.ball.velocity.dy = -abs(m.ball.velocity.dy)
			effects.append(.hapticLight)
		}

		if let reflection = reflect(ball: m.ball, against: m.leftPaddle, side: .left) {
			m.ball = reflection
			effects.append(.hapticMedium)
		}
		if let reflection = reflect(ball: m.ball, against: m.rightPaddle, side: .right) {
			m.ball = reflection
			effects.append(.hapticMedium)
		}

		if m.ball.position.x + m.ball.radius < 0 {
			m.rightScore += 1
			effects.append(.hapticSuccess)
			m.ball = PongModel.makeBall(in: m.court, servingTo: .right)
		} else if m.ball.position.x - m.ball.radius > m.court.width {
			m.leftScore += 1
			effects.append(.hapticSuccess)
			m.ball = PongModel.makeBall(in: m.court, servingTo: .left)
		}

		if m.winner != nil {
			m.isPaused = true
		}

		return .next(m, effects: effects)
	}

	private static func onPlayerInput(_ model: PongModel, input: PaddleInput) -> Next<PongModel, PongEffect> {
		var m = model
		switch input {
		case .up: m.leftPaddle.verticalVelocity = -playerPaddleSpeed
		case .down: m.leftPaddle.verticalVelocity = playerPaddleSpeed
		case .stop: m.leftPaddle.verticalVelocity = 0
		}
		return .next(m)
	}

	private static func onViewportChanged(_ model: PongModel, size: CGSize) -> Next<PongModel, PongEffect> {
		guard size.width > 0, size.height > 0 else { return .noChange }
		if !model.hasStarted {
			return .next(PongModel.initial(court: size))
		}
		var m = model
		let sx = size.width / max(model.court.width, 1)
		let sy = size.height / max(model.court.height, 1)
		m.court = size
		m.ball.position.x *= sx
		m.ball.position.y *= sy
		m.leftPaddle.center.x = 24 + m.leftPaddle.size.width / 2
		m.leftPaddle.center.y *= sy
		m.rightPaddle.center.x = size.width - 24 - m.rightPaddle.size.width / 2
		m.rightPaddle.center.y *= sy
		return .next(m)
	}

	private static func onReset(_ model: PongModel) -> Next<PongModel, PongEffect> {
		var m = PongModel.initial(court: model.court)
		m.isPaused = false
		m.hasStarted = true
		return .next(m)
	}

	private static func onTogglePause(_ model: PongModel) -> Next<PongModel, PongEffect> {
		guard model.winner == nil else { return .noChange }
		var m = model
		m.isPaused.toggle()
		m.hasStarted = true
		return .next(m)
	}

	// MARK: Physics helpers

	private static func clampPaddleY(_ y: CGFloat, paddle: Paddle, court: CGSize) -> CGFloat {
		let half = paddle.size.height / 2
		return max(half, min(court.height - half, y))
	}

	private static func reflect(ball: Ball, against paddle: Paddle, side: Side) -> Ball? {
		let halfW = paddle.size.width / 2
		let halfH = paddle.size.height / 2
		let minX = paddle.center.x - halfW
		let maxX = paddle.center.x + halfW
		let minY = paddle.center.y - halfH
		let maxY = paddle.center.y + halfH

		let nearestX = max(minX, min(maxX, ball.position.x))
		let nearestY = max(minY, min(maxY, ball.position.y))
		let dx = ball.position.x - nearestX
		let dy = ball.position.y - nearestY
		guard dx * dx + dy * dy <= ball.radius * ball.radius else { return nil }

		let movingTowardsPaddle = (side == .left && ball.velocity.dx < 0) || (side == .right && ball.velocity.dx > 0)
		guard movingTowardsPaddle else { return nil }

		var reflected = ball
		reflected.velocity.dx = -ball.velocity.dx * ballSpeedupOnPaddleHit
		let offset = (ball.position.y - paddle.center.y) / halfH
		reflected.velocity.dy += offset * 160
		let speed = sqrt(reflected.velocity.dx * reflected.velocity.dx + reflected.velocity.dy * reflected.velocity.dy)
		if speed > maxBallSpeed {
			let scale = maxBallSpeed / speed
			reflected.velocity.dx *= scale
			reflected.velocity.dy *= scale
		}
		switch side {
		case .left: reflected.position.x = maxX + ball.radius + 0.5
		case .right: reflected.position.x = minX - ball.radius - 0.5
		}
		return reflected
	}
}
