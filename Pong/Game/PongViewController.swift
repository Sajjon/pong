//
//  PongViewController.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import MobiusCore
import QuartzCore
import UIKit

final class PongViewController: UIViewController {
	private lazy var gameView = PongGameView()
	private var loopController: MobiusController<PongModel, PongEvent, PongEffect>?
	private var displayLink: CADisplayLink?
	private var lastTimestamp: CFTimeInterval = 0
	private var heldKeys: Set<UIKeyboardHIDUsage> = []
}

extension PongViewController {
	override var canBecomeFirstResponder: Bool { true }

	override func loadView() {
		view = gameView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		overrideUserInterfaceStyle = .dark
		buildLoop()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		loopController?.start()
		startDisplayLink()
		becomeFirstResponder()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		stopDisplayLink()
		loopController?.stop()
		resignFirstResponder()
	}

	// MARK: Keyboard

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		var handled = false
		for press in presses {
			guard let key = press.key else { continue }
			switch key.keyCode {
			case .keyboardUpArrow, .keyboardW:
				heldKeys.insert(key.keyCode)
				gameView.dispatch(.playerInput(.up))
				handled = true
			case .keyboardDownArrow, .keyboardS:
				heldKeys.insert(key.keyCode)
				gameView.dispatch(.playerInput(.down))
				handled = true
			case .keyboardSpacebar, .keyboardReturnOrEnter:
				gameView.dispatch(.togglePause)
				handled = true
			case .keyboardR:
				gameView.dispatch(.reset)
				handled = true
			default:
				break
			}
		}
		if !handled {
			super.pressesBegan(presses, with: event)
		}
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		var handled = false
		for press in presses {
			guard let key = press.key else { continue }
			switch key.keyCode {
			case .keyboardUpArrow, .keyboardW, .keyboardDownArrow, .keyboardS:
				heldKeys.remove(key.keyCode)
				if heldKeys.contains(.keyboardUpArrow) || heldKeys.contains(.keyboardW) {
					gameView.dispatch(.playerInput(.up))
				} else if heldKeys.contains(.keyboardDownArrow) || heldKeys.contains(.keyboardS) {
					gameView.dispatch(.playerInput(.down))
				} else {
					gameView.dispatch(.playerInput(.stop))
				}
				handled = true
			default:
				break
			}
		}
		if !handled {
			super.pressesEnded(presses, with: event)
		}
	}

	override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		heldKeys.removeAll()
		gameView.dispatch(.playerInput(.stop))
		super.pressesCancelled(presses, with: event)
	}
}


// MARK: Private
extension PongViewController {
	private func buildLoop() {
		let builder = Mobius
			.loop(update: PongLogic.update(model:event:), effectHandler: PongEffectHandler())

		let controller = builder.makeController(
			from: PongModel.initial(court: .zero),
			initiate: PongLogic.initiate
		)
		controller.connectView(gameView)
		loopController = controller
	}

	private func startDisplayLink() {
		let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
		link.add(to: .main, forMode: .common)
		displayLink = link
		lastTimestamp = 0
	}

	private func stopDisplayLink() {
		displayLink?.invalidate()
		displayLink = nil
	}

	@objc private func tick(_ link: CADisplayLink) {
		if lastTimestamp == 0 {
			lastTimestamp = link.timestamp
			return
		}
		let dt = CGFloat(min(link.timestamp - lastTimestamp, 1.0 / 30.0))
		lastTimestamp = link.timestamp
		gameView.dispatch(.tick(dt: dt))
	}
}

