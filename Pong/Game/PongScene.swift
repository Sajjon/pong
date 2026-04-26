//
//  PongScene.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The "canvas" the game is drawn on. A pure `UIView` with no knowledge
//  of Mobius, events, or game rules. It exposes one method:
//
//      func render(_ model: PongModel)
//
//  …which mutates its subviews to match the model. Caller's responsibility
//  to call this whenever the model changes — that caller is `PongGameView`,
//  via Mobius's accept closure.
//
//  Splitting rendering out of `PongGameView` keeps each class focused: the
//  scene knows pixels, the game view knows the Mobius wiring.
//
//  ── UIKit concepts you'll encounter here ─────────────────────────────────
//
//  • UIView: a rectangular drawable region. Has a `frame` (position +
//    size relative to its parent), `bounds` (its own coordinate space),
//    `subviews`, and a `layer` (the actual rendering object).
//
//  • UILabel: a UIView that draws text.
//
//  • CAShapeLayer: a Core Animation layer that draws an arbitrary path.
//    We use it for the dashed center line.
//
//  • layoutSubviews(): UIKit calls this on a view whenever its size
//    changes. The right place to lay out things that depend on `bounds`.
//

import UIKit

// MARK: - PongScene

final class PongScene: UIView {

	// MARK: - Immutable Properties
	//
	// `private let` because each subview is created once and never
	// replaced — only its frame/text/etc. mutate.

	private let leftPaddle       = UIView()
	private let rightPaddle      = UIView()
	private let ball             = UIView()
	/// The dashed line down the middle. `CAShapeLayer` lets us draw a
	/// vector path; cheaper than a UIBezierPath redrawn every frame.
	private let centerLine       = CAShapeLayer()
	private let leftScoreLabel   = UILabel()
	private let rightScoreLabel  = UILabel()
	/// Big text that says "Tap to start" / "Paused" / "<X> wins!".
	/// Hidden during normal play.
	private let overlayLabel     = UILabel()

	/// UIView's designated initializer is `init(frame:)`. We call super
	/// then build our subview hierarchy via `setup()`.
	override init(frame: CGRect) {
		super.init(frame: frame)
		setup()
	}

	/// `init?(coder:)` is required by `NSCoding` (used when a view is
	/// loaded from a storyboard/xib). We don't use Interface Builder —
	/// the project is fully programmatic — so this should never be
	/// called. `fatalError` makes that explicit.
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

// MARK: - API
extension PongScene {
	/// Update every subview to reflect `model`. Pure side effect: no
	/// state of our own changes; only the UIKit views.
	///
	/// Bails out early if the court hasn't been sized yet — without
	/// this guard, we'd compute negative widths and CG would warn.
	func render(_ model: PongModel) {
		guard model.court.width > 0, model.court.height > 0 else { return }

		// PADDLES — set bounds (size, in own coord space) then center
		// (position relative to superview). UIKit positions views by
		// `center` rather than top-left when you set it directly.
		leftPaddle.bounds = CGRect(origin: .zero, size: model.leftPaddle.size)
		leftPaddle.center = model.leftPaddle.center

		rightPaddle.bounds = CGRect(origin: .zero, size: model.rightPaddle.size)
		rightPaddle.center = model.rightPaddle.center

		// BALL — round it by setting `cornerRadius` to half its width.
		// (Because the ball is square, this turns it into a circle.)
		let diameter = model.ball.radius * 2
		ball.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
		ball.layer.cornerRadius = model.ball.radius
		ball.center = model.ball.position

		// SCORES — `\(...)` is Swift string interpolation.
		leftScoreLabel.text  = "\(model.leftScore)"
		rightScoreLabel.text = "\(model.rightScore)"

		// Position the score labels in the upper third, hugging the
		// center line.
		let labelWidth = bounds.width / 2 - 32
		leftScoreLabel.frame  = CGRect(x: 0,                     y: 32, width: labelWidth, height: 80)
		rightScoreLabel.frame = CGRect(x: bounds.width / 2 + 32, y: 32, width: labelWidth, height: 80)

		// OVERLAY label — center it vertically.
		overlayLabel.frame = CGRect(
			x: 24,
			y: bounds.midY - 70,
			width: bounds.width - 48,
			height: 140
		)

		// Decide overlay text and visibility. Order matters: a winner
		// takes priority over pause/start.
		if let winner = model.winner {
			overlayLabel.isHidden = false
			overlayLabel.text = "\(winner == .left ? "You" : "AI") wins!\nTap to play again"
		} else if !model.hasStarted {
			overlayLabel.isHidden = false
			overlayLabel.text = "Tap or press Space to start\nDrag or ↑/↓ (W/S) to move\nR to reset"
		} else if model.isPaused {
			overlayLabel.isHidden = false
			overlayLabel.text = "Paused — tap or press Space"
		} else {
			overlayLabel.isHidden = true
		}
	}
}

// MARK: - Override
extension PongScene {
	/// UIKit calls this whenever the view's size changes. It's also a
	/// good place to sync layer geometry (which doesn't autoresize) to
	/// the view's own bounds.
	override func layoutSubviews() {
		super.layoutSubviews()
		centerLine.frame = bounds
		// Recompute the path because it spans the full height/width.
		centerLine.path = makeCenterLinePath()
	}
}

// MARK: - Private
extension PongScene {
	/// Build the static visual hierarchy. Called once, from init.
	private func setup() {
		backgroundColor = .black

		// CENTER LINE — dashed, semi-transparent white.
		centerLine.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
		centerLine.lineWidth = 2
		centerLine.lineDashPattern = [8, 8]   // 8pt on, 8pt off
		centerLine.fillColor = UIColor.clear.cgColor
		layer.addSublayer(centerLine)

		// PADDLES — small white rounded rectangles.
		for paddle in [leftPaddle, rightPaddle] {
			paddle.backgroundColor = .white
			paddle.layer.cornerRadius = 3
			addSubview(paddle)
		}

		// BALL.
		ball.backgroundColor = .white
		addSubview(ball)

		// SCORE LABELS — monospaced digits so the score doesn't jiggle
		// when it changes width (e.g. "9" → "10").
		for (label, alignment) in [
			(leftScoreLabel,  NSTextAlignment.right),
			(rightScoreLabel, .left),
		] {
			label.font = .monospacedDigitSystemFont(ofSize: 72, weight: .bold)
			label.textColor = UIColor.white.withAlphaComponent(0.55)
			label.textAlignment = alignment
			label.text = "0"
			addSubview(label)
		}

		// OVERLAY label.
		overlayLabel.font = .systemFont(ofSize: 28, weight: .semibold)
		overlayLabel.textColor = .white
		overlayLabel.textAlignment = .center
		overlayLabel.numberOfLines = 0     // 0 = unlimited (allows \n)
		overlayLabel.isHidden = true       // hidden until the model says
		addSubview(overlayLabel)
	}

	/// Build the path for the dashed center line. Recomputed on every
	/// layout because it depends on `bounds`.
	private func makeCenterLinePath() -> CGPath {
		let path = UIBezierPath()
		path.move(to: CGPoint(x: bounds.midX, y: 0))
		path.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
		return path.cgPath
	}
}
