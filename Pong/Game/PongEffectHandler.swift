//
//  PongEffectHandler.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import MobiusCore
import UIKit

final class PongEffectHandler: Connectable {
	typealias Input = PongEffect
	typealias Output = PongEvent

	private let light = UIImpactFeedbackGenerator(style: .light)
	private let medium = UIImpactFeedbackGenerator(style: .medium)
	private let success = UINotificationFeedbackGenerator()

	init() {
		light.prepare()
		medium.prepare()
		success.prepare()
	}

	func connect(_ consumer: @escaping Consumer<PongEvent>) -> Connection<PongEffect> {
		Connection(
			acceptClosure: { [weak self] effect in
				guard let self else { return }
				switch effect {
				case .hapticLight:
					self.light.impactOccurred()
					self.light.prepare()
				case .hapticMedium:
					self.medium.impactOccurred()
					self.medium.prepare()
				case .hapticSuccess:
					self.success.notificationOccurred(.success)
					self.success.prepare()
				}
			},
			disposeClosure: {}
		)
	}
}
