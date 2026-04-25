//
//  PongViewController.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import MobiusCore
import UIKit

final class PongViewController: UIViewController {
	private lazy var gameView = PongGameView()

	private lazy var loopController: MobiusController<PongModel, PongEvent, PongEffect> = {
		let controller = Mobius
			.loop(update: PongLogic.update(model:event:), effectHandler: PongEffectHandler())
			.withEventSource(PongTickEventSource())
			.makeController(
				from: PongModel.initial(court: .zero),
				initiate: PongLogic.initiate
			)
		controller.connectView(gameView)
		return controller
	}()
}

extension PongViewController {
	override func loadView() {
		view = gameView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		overrideUserInterfaceStyle = .dark
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		loopController.start()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		loopController.stop()
	}
}
