//
//  KeyboardInputMapper.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  Translates raw UIKit key-press events into game events. Owns one piece
//  of state — the set of currently-held movement keys — so it can produce
//  the right "stop" event when the LAST direction key is released, even
//  if both ↑ and W (or ↓ and S) were pressed at the same time.
//
//  Why a separate object: that "set of held keys" is its own little state
//  machine. Putting it on the game view would make the view bigger and
//  mix two unrelated concerns (rendering hookup vs. keyboard logic).
//
//  How it talks to the loop: through a closure passed at construction
//  (`dispatch`). The view wires this to push events into Mobius. No
//  protocols, no delegates, no MobiusCore import needed here.
//
//  ── UIKit concepts used ──────────────────────────────────────────────────
//
//  • UIPress: a single physical-key event, similar to UITouch but for
//    keyboards / game controller buttons. Has a `.key` property (a
//    UIKey?) describing which physical key, modifiers, characters etc.
//
//  • UIKeyboardHIDUsage: an enum of every physical key on a keyboard,
//    using the USB HID standard. `.keyboardW`, `.keyboardSpacebar`, etc.
//

import UIKit

// MARK: - KeyboardInputMapper

final class KeyboardInputMapper {

	// MARK: - Immutable Properties

	/// Closure to send events into the game. Set once, at init, and
	/// captured for the lifetime of this mapper. `(PongEvent) -> Void`
	/// is the type — a function that takes a PongEvent and returns
	/// nothing.
	private let dispatch: (PongEvent) -> Void

	// MARK: - Mutable Properties

	/// The set of movement keys currently held down. Used to figure out
	/// the right `PaddleInput` to emit on key-up: if you release ↑ while
	/// W is still down, the paddle should keep moving up, not stop.
	private var heldKeys: Set<UIKeyboardHIDUsage> = []

	/// `@escaping` because we store the closure for later use (after
	/// init returns). Without `@escaping` Swift assumes the closure
	/// won't outlive the function.
	init(dispatch: @escaping (PongEvent) -> Void) {
		self.dispatch = dispatch
	}
}

// MARK: - API
extension KeyboardInputMapper {

	/// Forward a key-down batch to the mapper.
	///
	/// `@discardableResult` lets callers ignore the return value.
	/// Returns `true` if at least one key was a game key — the caller
	/// uses this to decide whether to forward the event up the
	/// responder chain (UIKit's bubble-up mechanism for unhandled
	/// events).
	@discardableResult
	func pressesBegan(_ presses: Set<UIPress>) -> Bool {
		var handled = false
		// One UIPress per key in the batch. Multiple keys can change
		// state in the same event (e.g. you press two keys with two
		// fingers in the same vsync interval).
		for press in presses {
			// `press.key` is optional because not every press
			// corresponds to a keyboard key (game controller button
			// events also flow through here).
			guard let key = press.key else { continue }
			switch key.keyCode {
			case .keyboardUpArrow, .keyboardW:
				heldKeys.insert(key.keyCode)
				dispatch(.playerInput(.up))
				handled = true
			case .keyboardDownArrow, .keyboardS:
				heldKeys.insert(key.keyCode)
				dispatch(.playerInput(.down))
				handled = true
			case .keyboardSpacebar, .keyboardReturnOrEnter:
				dispatch(.togglePause)
				handled = true
			case .keyboardR:
				dispatch(.reset)
				handled = true
			default:
				break  // not a game key; let the responder chain handle it
			}
		}
		return handled
	}

	/// Forward a key-up batch.
	///
	/// On release of a movement key, decide what direction (if any) to
	/// emit, based on the OTHER movement keys still held.
	@discardableResult
	func pressesEnded(_ presses: Set<UIPress>) -> Bool {
		var handled = false
		for press in presses {
			guard let key = press.key else { continue }
			switch key.keyCode {
			case .keyboardUpArrow, .keyboardW, .keyboardDownArrow, .keyboardS:
				heldKeys.remove(key.keyCode)
				// Resolve direction from what's still held. "Up" wins
				// if any up-key is still held, then "Down", else stop.
				if heldKeys.contains(.keyboardUpArrow) || heldKeys.contains(.keyboardW) {
					dispatch(.playerInput(.up))
				} else if heldKeys.contains(.keyboardDownArrow) || heldKeys.contains(.keyboardS) {
					dispatch(.playerInput(.down))
				} else {
					dispatch(.playerInput(.stop))
				}
				handled = true
			default:
				break
			}
		}
		return handled
	}

	/// Called when the system cancels presses (e.g. another app
	/// interrupted us). Drop all held state and stop the paddle —
	/// safer than assuming any specific direction.
	func pressesCancelled() {
		heldKeys.removeAll()
		dispatch(.playerInput(.stop))
	}
}
