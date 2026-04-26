//
//  PongTypes.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The "vocabulary" of the game. Three things, all pure data, no behavior:
//
//    • PongModel  — the entire state of the game at one instant in time.
//    • PongEvent  — every kind of input the game can receive (user input,
//                   per-frame ticks, viewport changes…). Sent INTO the
//                   Mobius loop.
//    • PongEffect — every kind of side effect the game asks for (haptics).
//                   Sent OUT of the Mobius loop, handled outside the pure
//                   logic.
//
//  In Mobius these three types are the contract between the pure logic
//  (PongLogic) and the outside world (UIKit, Core Haptics). Everything else
//  in the project is wiring around these three shapes.
//

import CoreGraphics  // CGPoint, CGSize, CGVector, CGFloat — pure geometry, no UI

// MARK: - Side

/// Which half of the court something is on. The left side is the human
/// player; the right side is the AI. Used to identify a paddle, decide which
/// way to serve the ball, and pick the winner.
enum Side: Equatable { case left, right }

// MARK: - PaddleInput

/// A direction command for the player's paddle. `.stop` means "don't move".
/// Both keyboard and pan-gesture handlers translate raw OS events into one
/// of these three values, then send `PongEvent.playerInput(_)` into the loop.
enum PaddleInput: Equatable { case up, down, stop }

// MARK: - Paddle

/// One paddle's geometry and current motion.
///
/// `verticalVelocity` is in points-per-second (positive = moving down,
/// negative = moving up, because UIKit's Y axis grows downward). The
/// physics step in `PongLogic.onTick` integrates this against `dt` to
/// advance `center.y` each frame.
struct Paddle: Equatable {
	/// Center point of the paddle, in the court's coordinate space.
	var center: CGPoint
	/// Width × height of the paddle.
	var size: CGSize
	/// Current vertical speed in points/second. Set by the input handler
	/// (player) or the AI (in `onTick`); zeroed by `.stop`.
	var verticalVelocity: CGFloat
}

// MARK: - Ball

/// The ball's geometry and current motion.
struct Ball: Equatable {
	/// Center point of the ball.
	var position: CGPoint
	/// Velocity in points/second. `dx` is horizontal, `dy` is vertical.
	var velocity: CGVector
	/// Half the ball's visual diameter. Used by collision math.
	var radius: CGFloat
}

// MARK: - PongModel

/// The full game state. In Mobius this is "the Model" — the single source
/// of truth that the pure update function transforms in response to events.
///
/// Important properties of a Mobius Model:
///  • Value type (`struct`) so updates are non-aliasing — copying is cheap
///    and means there's no shared mutable state.
///  • `Equatable` so Mobius can deduplicate redundant model deliveries to
///    consumers (the view only re-renders when the model actually changed).
///  • Holds *only* domain data — no UIKit, no closures, no references.
struct PongModel: Equatable {
	/// The size of the playing area. `.zero` until the view reports its
	/// real size via `PongEvent.viewportChanged`.
	var court: CGSize
	/// The ball.
	var ball: Ball
	/// The human player's paddle.
	var leftPaddle: Paddle
	/// The AI's paddle.
	var rightPaddle: Paddle
	/// Number of times the ball has gone past the right edge.
	var leftScore: Int
	/// Number of times the ball has gone past the left edge.
	var rightScore: Int
	/// Whether the simulation should advance on tick events. Used for the
	/// pre-game state and explicit pause via Space/tap.
	var isPaused: Bool
	/// Whether the player has ever pressed start. Used to decide what
	/// overlay text to show ("Tap to start" vs "Paused").
	var hasStarted: Bool

	/// Score required to win a match.
	static let winningScore = 7

	/// Build the initial model. The court can be zero if we don't know the
	/// view size yet — it gets filled in by the first viewportChanged event.
	static func initial(court: CGSize = .zero) -> PongModel {
		PongModel(
			court: court,
			ball: Self.makeBall(in: court, servingTo: .left),
			leftPaddle: Self.makePaddle(in: court, side: .left),
			rightPaddle: Self.makePaddle(in: court, side: .right),
			leftScore: 0,
			rightScore: 0,
			isPaused: true,    // game starts paused; user taps to begin
			hasStarted: false  // distinguishes "pre-game" from "paused mid-game"
		)
	}

	/// Computed: who won, if anyone. Computed properties on the Model are
	/// the right place for derived facts — no separate "ViewModel" needed.
	var winner: Side? {
		if leftScore >= Self.winningScore { return .left }
		if rightScore >= Self.winningScore { return .right }
		return nil
	}

	/// Construct a fresh ball at the center of the court, served toward the
	/// given side. Speed scales with court width so gameplay feels similar
	/// across phone/iPad/Mac.
	static func makeBall(in court: CGSize, servingTo side: Side) -> Ball {
		let speed: CGFloat = max(court.width, 1) * 0.45
		// Serving left = ball moves left (negative dx). Serving right = positive dx.
		let dx: CGFloat = side == .left ? -speed : speed
		// Random vertical sign so each serve isn't a straight line.
		let dy: CGFloat = (Bool.random() ? 1 : -1) * speed * 0.5
		return Ball(
			position: CGPoint(x: court.width / 2, y: court.height / 2),
			velocity: CGVector(dx: dx, dy: dy),
			radius: 8
		)
	}

	/// Construct a paddle on the requested side, vertically centered in
	/// the court.
	static func makePaddle(in court: CGSize, side: Side) -> Paddle {
		let width: CGFloat = 12
		// Paddle height tracks the court height but never below 60pt so it
		// stays usable on tiny windows.
		let height: CGFloat = max(court.height * 0.18, 60)
		let margin: CGFloat = 24
		// X is offset from the appropriate edge by margin + half-width so
		// the inner edge of the paddle sits exactly `margin` from the wall.
		let x: CGFloat = side == .left
			? margin + width / 2
			: court.width - margin - width / 2
		return Paddle(
			center: CGPoint(x: x, y: court.height / 2),
			size: CGSize(width: width, height: height),
			verticalVelocity: 0
		)
	}
}

// MARK: - PongEvent

/// Every kind of input that can drive a state change. In Mobius vocabulary
/// these are "Events" — they go INTO the loop and are the only way the
/// model can change. Effects (see below) are the *output* of state changes,
/// not inputs.
///
/// The naming pattern: case names describe *what happened*, not *what to
/// do*. The pure logic in `PongLogic` decides what to do in response.
///
/// Why `Equatable`: useful for testing the update function (you can assert
/// "given this model + this event, expect this next model"), and lets
/// Mobius dedupe identical events.
enum PongEvent: Equatable {
	/// `PongTickEventSource` fired. `dt` is seconds since the last tick
	/// (capped to 1/30 s to avoid huge jumps after backgrounding).
	case tick(dt: CGFloat)
	/// The user tapped the screen. Logic decides whether to togglePause or
	/// reset based on whether the game is over.
	case tap
	/// The user is dragging at this Y position. Logic decides which
	/// direction the paddle should move based on the paddle's current Y.
	case dragTo(y: CGFloat)
	/// The user lifted their finger. Logic stops the paddle.
	case dragEnded
	/// A direct paddle command. Comes from the keyboard handler (already
	/// decided by `KeyboardInputMapper`), and from drag → on/stop in logic.
	case playerInput(PaddleInput)
	/// The view's bounds changed (rotation, window resize, first layout).
	/// Carries the new court size; logic rescales positions to match.
	case viewportChanged(CGSize)
	/// Restart the match — reset scores and ball.
	case reset
	/// Flip the paused flag (only when there is no winner).
	case togglePause
}

// MARK: - PongEffect

/// Side effects requested by the pure logic. Mobius separates *what should
/// happen to state* (handled by update → Next.next) from *what should
/// happen in the world* (returned alongside the new model and handled
/// outside the loop by an effect handler).
///
/// We only have haptics here. If you added "play a sound" or "save high
/// score to disk", they would be new cases here.
enum PongEffect: Equatable {
	/// Tap haptic — used for ball/wall collisions.
	case hapticLight
	/// Stronger tap — used for ball/paddle hits.
	case hapticMedium
	/// Notification haptic — used when someone scores.
	case hapticSuccess
}
