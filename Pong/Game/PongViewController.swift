//
//  PongViewController.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The composition root. The smallest sensible thing a UIViewController
//  needs to do for this app:
//
//    • Own a `PongGameView` and install it as `self.view`.
//    • Build a `MobiusController` that wires the pure logic, the effect
//      handler, and the tick event source together.
//    • Connect the view to the controller, then start/stop the loop in
//      response to the view appearing/disappearing.
//
//  Notice what's NOT here: no display link, no keyboard handling, no
//  game state, no rendering. Each of those lives in its own file. This
//  class is ~30 lines because everything else has been pulled out.
//
//  ── Mobius concept introduced here: `MobiusController` ───────────────────
//
//  A `MobiusController<Model, Event, Effect>` is the runtime handle to a
//  Mobius loop. You build it once via `Mobius.loop(...).makeController`,
//  attach views via `.connectView(_:)`, and use `.start()` / `.stop()`
//  to run/pause the loop. While running it: receives events, runs the
//  pure update, dispatches effects, and pushes models to connected views.
//

import MobiusCore  // Mobius, MobiusController
import UIKit

// MARK: - PongViewController

final class PongViewController: UIViewController {

	/// The game's UIView. `lazy` so it isn't created until first access
	/// (`loadView` triggers it).
	private lazy var gameView = PongGameView()

	/// The Mobius runtime. `lazy` because:
	///   • It needs `gameView` to exist (we call `connectView(gameView)`).
	///   • Building it doesn't happen until something asks for it,
	///     which lets `loadView` and `viewDidLoad` run first.
	///
	/// The closure runs once, the first time `loopController` is read
	/// (which happens in `viewDidAppear`'s `loopController.start()`).
	private lazy var loopController: MobiusController<PongModel, PongEvent, PongEffect> = {
		let controller = Mobius
			// `Mobius.loop(update:effectHandler:)` returns a builder.
			// `update(model:event:)` is the function reference syntax —
			// we pass the function itself, not call it.
			.loop(
				update: PongLogic.update(model:event:),
				effectHandler: PongEffectHandler()
			)
			// Attach the clock as an event source. The loop will
			// auto-start it on `controller.start()` and stop it on
			// `controller.stop()`.
			.withEventSource(PongTickEventSource())
			// Materialize the builder into a runtime controller.
			//   `from:`     — the seed model.
			//   `initiate:` — the function to call when the loop
			//                 starts (returns the first model + any
			//                 startup effects).
			.makeController(
				from: PongModel.initial(court: .zero),
				initiate: PongLogic.initiate
			)
		// Wire the view as the loop's renderer + event source.
		// After this, model updates flow into `gameView.connect`'s
		// acceptClosure, and gameView events flow into the loop.
		controller.connectView(gameView)
		return controller
	}()
}

extension PongViewController {

	/// UIKit calls `loadView` to create the view controller's root view.
	/// Default behavior is to look for a nib/storyboard; we override
	/// to install our programmatic view directly.
	override func loadView() {
		view = gameView
	}

	/// Called once after the view is loaded. We just set the dark
	/// theme; everything else is handled by the lazy `loopController`.
	override func viewDidLoad() {
		super.viewDidLoad()
		// Force dark mode — Pong looks better on a black court
		// regardless of system theme.
		overrideUserInterfaceStyle = .dark
	}

	/// Called every time the view becomes visible. Start (or resume)
	/// the loop here so the game pauses when you navigate away.
	///
	/// Reading `loopController` for the first time triggers the lazy
	/// initializer above. Subsequent `viewDidAppear` calls just
	/// read the same controller and call `.start()` again.
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		loopController.start()
	}

	/// Called when the view is about to leave the screen. Stop the
	/// loop so we don't run physics in the background.
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		loopController.stop()
	}
}
