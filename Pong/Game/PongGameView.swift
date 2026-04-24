//
//  PongGameView.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import MobiusCore
import UIKit

final class PongGameView: UIView, Connectable {
	typealias Input = PongModel
	typealias Output = PongEvent

	private let leftPaddle = UIView()
	private let rightPaddle = UIView()
	private let ball = UIView()
	private let centerLine = CAShapeLayer()
	private let leftScoreLabel = UILabel()
	private let rightScoreLabel = UILabel()
	private let overlayLabel = UILabel()

	private var currentModel: PongModel?
	private var eventConsumer: Consumer<PongEvent>?

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupViews()
		setupGestures()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		centerLine.frame = bounds
		centerLine.path = makeCenterLinePath()
		eventConsumer?(.viewportChanged(bounds.size))
		if let model = currentModel {
			render(model)
		}
	}

	func dispatch(_ event: PongEvent) {
		eventConsumer?(event)
	}

	func connect(_ consumer: @escaping Consumer<PongEvent>) -> Connection<PongModel> {
		eventConsumer = consumer
		if bounds.size.width > 0, bounds.size.height > 0 {
			consumer(.viewportChanged(bounds.size))
		}
		return Connection(
			acceptClosure: { [weak self] model in
				self?.currentModel = model
				self?.render(model)
			},
			disposeClosure: { [weak self] in
				self?.eventConsumer = nil
			}
		)
	}

	private func setupViews() {
		backgroundColor = .black

		centerLine.strokeColor = UIColor.white.withAlphaComponent(0.35).cgColor
		centerLine.lineWidth = 2
		centerLine.lineDashPattern = [8, 8]
		centerLine.fillColor = UIColor.clear.cgColor
		layer.addSublayer(centerLine)

		for paddle in [leftPaddle, rightPaddle] {
			paddle.backgroundColor = .white
			paddle.layer.cornerRadius = 3
			addSubview(paddle)
		}

		ball.backgroundColor = .white
		addSubview(ball)

		for (label, alignment) in [(leftScoreLabel, NSTextAlignment.right), (rightScoreLabel, .left)] {
			label.font = .monospacedDigitSystemFont(ofSize: 72, weight: .bold)
			label.textColor = UIColor.white.withAlphaComponent(0.55)
			label.textAlignment = alignment
			label.text = "0"
			addSubview(label)
		}

		overlayLabel.font = .systemFont(ofSize: 28, weight: .semibold)
		overlayLabel.textColor = .white
		overlayLabel.textAlignment = .center
		overlayLabel.numberOfLines = 0
		overlayLabel.isHidden = true
		addSubview(overlayLabel)
	}

	private func setupGestures() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
		addGestureRecognizer(tap)

		let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		addGestureRecognizer(pan)
	}

	@objc private func handleTap() {
		if let winner = currentModel?.winner {
			_ = winner
			eventConsumer?(.reset)
		} else {
			eventConsumer?(.togglePause)
		}
	}

	@objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
		guard let model = currentModel else { return }
		switch gesture.state {
		case .began, .changed:
			let location = gesture.location(in: self)
			let target = location.y
			let current = model.leftPaddle.center.y
			let threshold: CGFloat = 6
			if target < current - threshold {
				eventConsumer?(.playerInput(.up))
			} else if target > current + threshold {
				eventConsumer?(.playerInput(.down))
			} else {
				eventConsumer?(.playerInput(.stop))
			}
		case .ended, .cancelled, .failed:
			eventConsumer?(.playerInput(.stop))
		default:
			break
		}
	}

	private func render(_ model: PongModel) {
		guard model.court.width > 0, model.court.height > 0 else { return }

		leftPaddle.bounds = CGRect(origin: .zero, size: model.leftPaddle.size)
		leftPaddle.center = model.leftPaddle.center

		rightPaddle.bounds = CGRect(origin: .zero, size: model.rightPaddle.size)
		rightPaddle.center = model.rightPaddle.center

		let diameter = model.ball.radius * 2
		ball.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
		ball.layer.cornerRadius = model.ball.radius
		ball.center = model.ball.position

		leftScoreLabel.text = "\(model.leftScore)"
		rightScoreLabel.text = "\(model.rightScore)"
		let labelWidth: CGFloat = bounds.width / 2 - 32
		leftScoreLabel.frame = CGRect(x: 0, y: 32, width: labelWidth, height: 80)
		rightScoreLabel.frame = CGRect(x: bounds.width / 2 + 32, y: 32, width: labelWidth, height: 80)

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
		overlayLabel.frame = CGRect(
			x: 24,
			y: bounds.midY - 70,
			width: bounds.width - 48,
			height: 140
		)
	}

	private func makeCenterLinePath() -> CGPath {
		let path = UIBezierPath()
		path.move(to: CGPoint(x: bounds.midX, y: 0))
		path.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
		return path.cgPath
	}
}
