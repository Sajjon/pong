//
//  PongLogic.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The PURE BRAIN of the game. Two functions matter:
//
//    initiate(_:) — what the loop does the moment it starts (just hand
//                   back the model unchanged, here).
//
//    update(model:event:) — given the *current* model and an *incoming*
//                   event, return the *next* model and any side effects
//                   to perform. Pure: no UIKit, no I/O, no random clocks.
//                   Same inputs → same outputs, every time.
//
//  Mobius's golden rule: this function is the ONLY place the model
//  changes. The view never edits the model. The effect handler never
//  edits the model. Tests of this file are tests of the entire game.
//
//  Why `enum PongLogic` (with no cases): Swift idiom for "namespace of
//  static functions". You can't accidentally instantiate it.
//

import CoreGraphics  // CGFloat math, no UI
import MobiusCore    // First, Next, the return types our two functions produce

enum PongLogic {

	// MARK: - Tuning constants
	//
	// Game feel knobs. Pure numbers, deliberately gathered at the top of
	// the file so a designer can tweak them without hunting through code.

	/// Pixels-per-second the player paddle travels while a direction key
	/// is held. Higher = twitchier controls.
	static let playerPaddleSpeed: CGFloat = 520

	/// Hard cap on the AI paddle's speed. Lower = AI is easier to beat.
	static let aiPaddleMaxSpeed: CGFloat = 380

	/// Multiplier on (ball.y − paddle.y) when computing the AI's desired
	/// velocity. Higher = AI snaps to the ball faster.
	static let aiReactionGain: CGFloat = 6

	/// The ball gets slightly faster every time it bounces off a paddle,
	/// to keep rallies escalating.
	static let ballSpeedupOnPaddleHit: CGFloat = 1.06

	/// Absolute speed cap so escalation eventually stops.
	static let maxBallSpeed: CGFloat = 1400

	// MARK: - Initiate
	//
	// `initiate` is called by Mobius once when the loop starts (technically
	// when `MobiusController.start()` runs). Its job: take the seed model
	// and decide whether to mutate it AND whether to dispatch any startup
	// effects.
	//
	// Here we just return the model unchanged with no effects — there's
	// nothing special to do at startup.

	/// Mobius "initiate" hook. Called once at controller startup.
	static func initiate(_ model: PongModel) -> First<PongModel, PongEffect> {
		// `First` = "the first model the loop publishes". Pass the model
		// unchanged. Could also include startup effects via
		// `First(model: model, effects: [...])` if needed.
		First(model: model)
	}

	// MARK: - Update
	//
	// The big one. Every event goes through here. The body is just a
	// dispatch table — each case delegates to a tiny handler so each
	// concern can be read (and unit-tested) in isolation.

	/// Mobius "update" function. Pure: `(Model, Event) → (Model, [Effect])`.
	///
	/// `Next` is Mobius's return type. It can be:
	///   • `.noChange` — model and effects both unchanged
	///   • `.next(model)` — new model, no effects
	///   • `.next(model, effects: [...])` — new model AND effects to run
	///   • `.dispatchEffects([...])` — same model, just run effects
	static func update(model: PongModel, event: PongEvent) -> Next<PongModel, PongEffect> {
		switch event {
		case .tick(let dt):              return onTick(model, dt: dt)
		case .tap:                       return onTap(model)
		case .dragTo(let y):             return onDragTo(model, y: y)
		case .dragEnded:                 return onPlayerInput(model, input: .stop)
		case .playerInput(let input):    return onPlayerInput(model, input: input)
		case .viewportChanged(let size): return onViewportChanged(model, size: size)
		case .reset:                     return onReset(model)
		case .togglePause:               return onTogglePause(model)
		}
		// Note: no `default:` — Swift forces us to handle every case, so
		// adding a new event causes a compile error here, reminding us to
		// decide what should happen.
	}

	// MARK: - Event handlers
	//
	// One function per event. Each is `static`, returns `Next`, and never
	// touches anything outside its inputs.

	/// Advance the simulation by `dt` seconds.
	///
	/// This is where ALL the physics live. Step by step:
	///   1. Bail if paused / over / not yet sized.
	///   2. Move the player paddle by its velocity.
	///   3. Update + move the AI paddle.
	///   4. Move the ball.
	///   5. Bounce ball off top/bottom walls.
	///   6. Bounce ball off paddles.
	///   7. Check for scoring (ball past left/right edge).
	///   8. If someone reached `winningScore`, pause.
	///
	/// Effects emitted along the way: haptics for each bounce/score.
	private static func onTick(_ model: PongModel, dt: CGFloat) -> Next<PongModel, PongEffect> {
		// Guard: nothing to simulate if we're paused, the game is over,
		// or the court hasn't been sized yet (court.width == 0 means the
		// view hasn't reported its size).
		guard !model.isPaused, model.winner == nil, model.court.width > 0 else {
			return .noChange
		}

		// Make a mutable copy. The original `model` parameter is a `let`
		// (Swift function parameters are immutable by default). Copying a
		// struct is cheap.
		var m = model

		// We accumulate effects as we discover them, then return them all
		// at once. Mobius will dispatch each one to the effect handler.
		var effects: [PongEffect] = []

		// 1) Player paddle: position += velocity × dt. Clamp so it can't
		//    leave the court vertically.
		m.leftPaddle.center.y = clampPaddleY(
			m.leftPaddle.center.y + m.leftPaddle.verticalVelocity * dt,
			paddle: m.leftPaddle,
			court: m.court
		)

		// 2) AI paddle: aim toward the ball's Y. The "gain" controls how
		//    aggressively it tracks; the cap keeps it beatable.
		let deltaY = m.ball.position.y - m.rightPaddle.center.y
		let desired = max(-aiPaddleMaxSpeed, min(aiPaddleMaxSpeed, deltaY * aiReactionGain))
		m.rightPaddle.verticalVelocity = desired
		m.rightPaddle.center.y = clampPaddleY(
			m.rightPaddle.center.y + m.rightPaddle.verticalVelocity * dt,
			paddle: m.rightPaddle,
			court: m.court
		)

		// 3) Ball: standard p += v × dt.
		m.ball.position.x += m.ball.velocity.dx * dt
		m.ball.position.y += m.ball.velocity.dy * dt

		// 4) Top/bottom wall collisions. We snap the ball back inside the
		//    court and flip dy. Using abs() ensures we don't double-flip
		//    if the ball is already moving the right way.
		if m.ball.position.y - m.ball.radius <= 0 {
			m.ball.position.y = m.ball.radius
			m.ball.velocity.dy = abs(m.ball.velocity.dy)   // force "down"
			effects.append(.hapticLight)
		} else if m.ball.position.y + m.ball.radius >= m.court.height {
			m.ball.position.y = m.court.height - m.ball.radius
			m.ball.velocity.dy = -abs(m.ball.velocity.dy)  // force "up"
			effects.append(.hapticLight)
		}

		// 5) Paddle collisions. `reflect` returns the new ball state if a
		//    collision happened, or nil if not. We check both paddles.
		if let reflection = reflect(ball: m.ball, against: m.leftPaddle, side: .left) {
			m.ball = reflection
			effects.append(.hapticMedium)
		}
		if let reflection = reflect(ball: m.ball, against: m.rightPaddle, side: .right) {
			m.ball = reflection
			effects.append(.hapticMedium)
		}

		// 6) Scoring: ball fully past one edge. Increment the *opposing*
		//    score, play a success haptic, and serve a fresh ball toward
		//    the side that lost the point (classic Pong convention).
		if m.ball.position.x + m.ball.radius < 0 {
			m.rightScore += 1
			effects.append(.hapticSuccess)
			m.ball = PongModel.makeBall(in: m.court, servingTo: .right)
		} else if m.ball.position.x - m.ball.radius > m.court.width {
			m.leftScore += 1
			effects.append(.hapticSuccess)
			m.ball = PongModel.makeBall(in: m.court, servingTo: .left)
		}

		// 7) Match over → freeze the simulation. The view will show a
		//    "<X> wins!" overlay because of the model.winner being
		//    non-nil.
		if m.winner != nil {
			m.isPaused = true
		}

		return .next(m, effects: effects)
	}

	/// Player tapped (or pressed Space). If the game is over, restart;
	/// otherwise toggle pause. Decision lives here, NOT in the view, so
	/// the view can stay stateless.
	private static func onTap(_ model: PongModel) -> Next<PongModel, PongEffect> {
		if model.winner != nil {
			return onReset(model)
		}
		return onTogglePause(model)
	}

	/// Player is dragging. Translate the absolute Y into a paddle command
	/// based on whether the touch is above or below the paddle's center.
	/// The threshold prevents jitter when the finger is right on the
	/// paddle.
	private static func onDragTo(_ model: PongModel, y: CGFloat) -> Next<PongModel, PongEffect> {
		let threshold: CGFloat = 6
		let current = model.leftPaddle.center.y
		let input: PaddleInput
		if y < current - threshold {
			input = .up
		} else if y > current + threshold {
			input = .down
		} else {
			input = .stop
		}
		return onPlayerInput(model, input: input)
	}

	/// Set the player paddle's velocity from a directional command.
	/// Reused by `.playerInput`, `.dragEnded`, and `onDragTo`.
	private static func onPlayerInput(_ model: PongModel, input: PaddleInput) -> Next<PongModel, PongEffect> {
		var m = model
		switch input {
		case .up:   m.leftPaddle.verticalVelocity = -playerPaddleSpeed  // negative Y = up
		case .down: m.leftPaddle.verticalVelocity =  playerPaddleSpeed
		case .stop: m.leftPaddle.verticalVelocity = 0
		}
		return .next(m)
	}

	/// The view's bounds changed (rotation, window resize, first layout).
	///
	/// Two cases:
	///   • Pre-game (`!hasStarted`): just rebuild a fresh model with the
	///     new size. Nothing to preserve.
	///   • Mid-game: rescale positions proportionally so the ball and
	///     paddles stay in roughly the right place after a resize.
	private static func onViewportChanged(_ model: PongModel, size: CGSize) -> Next<PongModel, PongEffect> {
		guard size.width > 0, size.height > 0 else { return .noChange }
		if !model.hasStarted {
			return .next(PongModel.initial(court: size))
		}
		var m = model
		// Ratio of new size to old size, used to rescale every position.
		let sx = size.width  / max(model.court.width,  1)
		let sy = size.height / max(model.court.height, 1)
		m.court = size
		m.ball.position.x *= sx
		m.ball.position.y *= sy
		// X for paddles is determined by the side margin, not by scaling
		// (we want the paddles to sit a fixed 24pt from the new edges).
		m.leftPaddle.center.x  = 24 + m.leftPaddle.size.width / 2
		m.leftPaddle.center.y *= sy
		m.rightPaddle.center.x = size.width - 24 - m.rightPaddle.size.width / 2
		m.rightPaddle.center.y *= sy
		return .next(m)
	}

	/// Reset the match: scores back to 0, fresh ball, NOT paused (so the
	/// next tick starts the action immediately), `hasStarted` flips true.
	private static func onReset(_ model: PongModel) -> Next<PongModel, PongEffect> {
		var m = PongModel.initial(court: model.court)
		m.isPaused = false
		m.hasStarted = true
		return .next(m)
	}

	/// Flip the paused flag. Refuses to do anything once a winner exists —
	/// you can only escape the end-of-match state with `.reset`.
	private static func onTogglePause(_ model: PongModel) -> Next<PongModel, PongEffect> {
		guard model.winner == nil else { return .noChange }
		var m = model
		m.isPaused.toggle()
		m.hasStarted = true
		return .next(m)
	}

	// MARK: - Physics helpers

	/// Clamp a paddle's Y so the paddle stays fully inside the court.
	private static func clampPaddleY(_ y: CGFloat, paddle: Paddle, court: CGSize) -> CGFloat {
		let half = paddle.size.height / 2
		return max(half, min(court.height - half, y))
	}

	/// Test the ball against a paddle. Returns the post-bounce ball state
	/// if a collision happened, or nil if no collision.
	///
	/// Algorithm: nearest-point-on-rectangle distance test. Find the point
	/// on the paddle closest to the ball, measure how far the ball center
	/// is from that point — if less than the radius, they overlap.
	///
	/// Then we additionally require the ball to be moving *toward* the
	/// paddle, otherwise we'd flip the velocity again on the next frame
	/// while the ball is still inside the paddle (causing it to oscillate
	/// and "stick").
	///
	/// On bounce we:
	///  1) flip dx and apply the speedup multiplier
	///  2) tilt the ball based on where on the paddle it hit (hitting the
	///     paddle near the top deflects upward, near the bottom downward)
	///  3) clamp total speed to `maxBallSpeed`
	///  4) push the ball one radius outside the paddle on the correct
	///     side, so the next frame's collision test can't re-collide
	private static func reflect(ball: Ball, against paddle: Paddle, side: Side) -> Ball? {
		let halfW = paddle.size.width  / 2
		let halfH = paddle.size.height / 2
		// Bounding box of the paddle.
		let minX = paddle.center.x - halfW
		let maxX = paddle.center.x + halfW
		let minY = paddle.center.y - halfH
		let maxY = paddle.center.y + halfH

		// Closest point on the paddle's rectangle to the ball center.
		let nearestX = max(minX, min(maxX, ball.position.x))
		let nearestY = max(minY, min(maxY, ball.position.y))
		// Squared distance — using squared lengths avoids a sqrt and is
		// fine when comparing to a known threshold (radius²).
		let dx = ball.position.x - nearestX
		let dy = ball.position.y - nearestY
		guard dx * dx + dy * dy <= ball.radius * ball.radius else { return nil }

		// Anti-stick guard.
		let movingTowardsPaddle =
			(side == .left  && ball.velocity.dx < 0) ||
			(side == .right && ball.velocity.dx > 0)
		guard movingTowardsPaddle else { return nil }

		var reflected = ball
		// Horizontal flip + small speed-up.
		reflected.velocity.dx = -ball.velocity.dx * ballSpeedupOnPaddleHit
		// Add some Y-spin based on where it hit (-1…+1 across paddle).
		let offset = (ball.position.y - paddle.center.y) / halfH
		reflected.velocity.dy += offset * 160

		// Speed cap.
		let speed = sqrt(reflected.velocity.dx * reflected.velocity.dx +
		                 reflected.velocity.dy * reflected.velocity.dy)
		if speed > maxBallSpeed {
			let scale = maxBallSpeed / speed
			reflected.velocity.dx *= scale
			reflected.velocity.dy *= scale
		}

		// Push the ball just outside the paddle so we can't re-collide
		// next frame. The +0.5 / -0.5 is paranoia for floating-point
		// rounding.
		switch side {
		case .left:  reflected.position.x = maxX + ball.radius + 0.5
		case .right: reflected.position.x = minX - ball.radius - 0.5
		}
		return reflected
	}
}
