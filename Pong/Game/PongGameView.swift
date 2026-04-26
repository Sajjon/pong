//
//  PongGameView.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The thin façade between Mobius and the rest of the UI. Three jobs:
//
//    1. Hold a `PongScene` subview and forward `render(model)` to it.
//    2. Translate raw UIKit user input (touch + keyboard) into PongEvents.
//    3. Conform to Mobius's `Connectable` so the loop can attach to it.
//
//  This view does NOT make any game decisions. Tap → `.tap`, drag → `.dragTo`.
//  All "what should happen?" reasoning lives in `PongLogic`. That's why
//  there's no model snapshot here — the view doesn't read the model to
//  decide anything.
//
//  ── Mobius concept introduced here: `Connectable` ────────────────────────
//
//  `Connectable<Input, Output>` is Mobius's universal "attach me to the
//  loop" protocol. You implement `connect(_:)`, which Mobius calls once.
//  You're given a `Consumer<Output>` (a function you call to push events
//  back into the loop) and you return a `Connection<Input>` that
//  describes how to receive inputs (models, in our case) and how to
//  clean up.
//
//  For the view: Input = `PongModel` (the loop tells us "render this"),
//  Output = `PongEvent` (we tell the loop "user did this").
//

import MobiusCore  // Connectable, Connection, Consumer
import UIKit

// MARK: - PongGameView

final class PongGameView: UIView, Connectable {
	/// Mobius hands us models via this type.
	typealias Input  = PongModel
	/// Mobius accepts events from us of this type.
	typealias Output = PongEvent

	// MARK: - Immutable Properties

	/// The thing that actually draws pixels.
	private let scene = PongScene()

	/// Keyboard input handler. `lazy` because the closure it takes
	/// captures `self` (`[weak self]`) and we can't use `self` in a
	/// stored-property initializer until init has finished.
	private lazy var keyboard = KeyboardInputMapper { [weak self] event in
		self?.eventConsumer?(event)
	}

	// MARK: - Connection Port

	/// Set by Mobius in `connect(_:)`, cleared in the dispose closure.
	/// Must be `var` because the connection lifecycle goes
	/// nil → consumer → nil. See discussion in commit history if curious.
	private var eventConsumer: Consumer<PongEvent>?

	override init(frame: CGRect) {
		super.init(frame: frame)
		addSubview(scene)
		setupGestures()
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

// MARK: - Override
extension PongGameView {
	/// Required to receive `pressesBegan` etc. on a UIView. Default is
	/// false for views (only view controllers default true).
	override var canBecomeFirstResponder: Bool { true }

	/// UIKit calls this when the view is added to (or removed from) a
	/// window. We use the "added to window" case to grab keyboard
	/// focus automatically. Without this, `pressesBegan` would never
	/// fire on us.
	override func didMoveToWindow() {
		super.didMoveToWindow()
		if window != nil {
			becomeFirstResponder()
		}
	}

	/// UIKit calls this whenever this view's bounds change (rotation,
	/// initial layout, window resize). Two jobs:
	///   1. Resize the scene to fill us.
	///   2. Tell the loop the new viewport size.
	override func layoutSubviews() {
		super.layoutSubviews()
		scene.frame = bounds
		// Optional-chaining: do nothing if the loop isn't connected
		// yet (e.g. very first layout, before `connect(_:)` has been
		// called).
		eventConsumer?(.viewportChanged(bounds.size))
	}

	// MARK: Keyboard
	//
	// UIKit's "responder chain" delivers key events starting at the
	// first responder and bubbling up. We override the press methods
	// here, hand them to the mapper, and forward to `super` only if
	// the mapper didn't claim the event — that way text-shortcut keys
	// we don't care about can still be handled elsewhere.

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if !keyboard.pressesBegan(presses) {
			super.pressesBegan(presses, with: event)
		}
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if !keyboard.pressesEnded(presses) {
			super.pressesEnded(presses, with: event)
		}
	}

	override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		keyboard.pressesCancelled()
		super.pressesCancelled(presses, with: event)
	}
}

// MARK: - Mobius
extension PongGameView {
	/// Mobius calls this once during loop wiring.
	///
	/// - Parameter consumer: Closure to push events into the loop.
	/// - Returns: A `Connection<PongModel>` whose `acceptClosure` fires
	///   every time Mobius produces a new model, and whose
	///   `disposeClosure` fires when the loop tears down.
	func connect(_ consumer: @escaping Consumer<PongEvent>) -> Connection<PongModel> {
		eventConsumer = consumer

		// If we already have a non-zero size by the time Mobius
		// connects (likely — the view was laid out before viewDidAppear
		// triggered loop start), tell the loop right away. Otherwise
		// the first viewportChanged comes from `layoutSubviews`.
		if bounds.size.width > 0, bounds.size.height > 0 {
			consumer(.viewportChanged(bounds.size))
		}

		return Connection(
			acceptClosure: { [weak self] model in
				// Mobius gives us a fresh model — paint it.
				self?.scene.render(model)
			},
			disposeClosure: { [weak self] in
				// Loop is going away; release the consumer so we
				// don't try to push events into a torn-down loop.
				self?.eventConsumer = nil
			}
		)
	}
}

// MARK: - Private
extension PongGameView {

	/// Wire up touch gestures. UIGestureRecognizer + target/action is
	/// the classic UIKit pattern: create the recognizer, point it at a
	/// method on `self`, attach it to the view.
	private func setupGestures() {
		let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
		addGestureRecognizer(tap)

		let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
		addGestureRecognizer(pan)
	}

	/// `@objc` exposes this method to the Objective-C runtime, which
	/// is how UIGestureRecognizer's target/action mechanism finds it.
	/// (Selectors are an Objective-C concept.)
	@objc func handleTap() {
		// Just report the raw event. PongLogic.onTap decides what to do.
		eventConsumer?(.tap)
	}

	/// Handle pan gesture state transitions. UIPanGestureRecognizer
	/// transitions through .began → .changed → .ended (or .cancelled
	/// / .failed); we report drag-to during the move and drag-end
	/// when the touch lifts.
	@objc func handlePan(_ gesture: UIPanGestureRecognizer) {
		switch gesture.state {
		case .began, .changed:
			eventConsumer?(.dragTo(y: gesture.location(in: self).y))
		case .ended, .cancelled, .failed:
			eventConsumer?(.dragEnded)
		default:
			break  // .possible / .recognized — nothing to do
		}
	}
}
