//
//  PongEffectHandler.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The "hands" that perform the side effects requested by the pure logic.
//
//  In Mobius, when `update` returns `Next.next(model, effects: [...])`,
//  Mobius takes those effects and hands them, one at a time, to the
//  effect handler — which is just a `Connectable<Input, Output>` where
//  Input is the Effect type and Output is the Event type.
//
//  Two ideas to internalize:
//
//  1. The effect handler is the ONLY place where impure stuff happens
//     (haptics, network, file I/O). Keeping all impurity here means the
//     update function stays trivially testable.
//
//  2. The effect handler can also send NEW events back into the loop
//     (that's why its Output is PongEvent). For example, "save to disk"
//     could emit `.saveCompleted` on success. We don't use that here —
//     haptics fire-and-forget — so our `consumer` parameter is unused.
//
//  Note: feedback generators are constructed inside the main-queue
//  closure rather than stored as `let` properties. Mobius dispatches
//  effects on its own queue, and `UIFeedbackGenerator` must be touched
//  only on the main thread; constructing it inside `DispatchQueue.main.async`
//  guarantees that.
//

import MobiusCore  // Connectable, Connection, Consumer
import UIKit       // UIImpactFeedbackGenerator, UINotificationFeedbackGenerator

// MARK: - PongEffectHandler

final class PongEffectHandler: Connectable {
	/// What this handler RECEIVES — Mobius hands us effects.
	typealias Input  = PongEffect
	/// What this handler can SEND BACK — Mobius accepts events from us.
	/// We don't actually emit any, but the protocol requires the type.
	typealias Output = PongEvent

	/// Mobius calls this once when it wires up the handler.
	///
	/// - Parameter consumer: a closure we can call to push events INTO
	///   the loop. We don't use it here — haptics don't produce events.
	/// - Returns: a `Connection` whose `acceptClosure` is invoked every
	///   time Mobius wants to perform an effect, and whose `disposeClosure`
	///   is invoked when the loop tears down.
	func connect(_ consumer: @escaping Consumer<PongEvent>) -> Connection<PongEffect> {
		Connection(
			acceptClosure: { effect in
				// Mobius dispatches effects from its own serial queue,
				// not main. UIFeedbackGenerator is MainActor-only —
				// constructing AND invoking it must happen on main.
				DispatchQueue.main.async {
					switch effect {
					case .hapticLight:
						UIImpactFeedbackGenerator(style: .light).impactOccurred()
					case .hapticMedium:
						UIImpactFeedbackGenerator(style: .medium).impactOccurred()
					case .hapticSuccess:
						UINotificationFeedbackGenerator().notificationOccurred(.success)
					}
				}
			},
			// Nothing persistent to clean up.
			disposeClosure: {}
		)
	}
}
