//
//  PongTickEventSource.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//
//  ── What this file is ────────────────────────────────────────────────────
//  The per-frame tick source. An "event source" in Mobius vocabulary:
//  an object that produces events from outside the loop, on its own
//  schedule, without being asked.
//
//  This one wraps `CADisplayLink` (UIKit's vsync-aligned timer that fires
//  once per display refresh — typically 60 or 120 Hz). On each fire it
//  computes the elapsed time since the previous fire and emits a
//  `PongEvent.tick(dt:)` into the loop, which causes the physics step in
//  `PongLogic.onTick` to run.
//
//  Why a separate object (and not just a property on the view controller):
//  it has its OWN state (the display link itself, the previous timestamp,
//  the consumer closure) that has nothing to do with view controllers.
//  Putting it in its own class means the VC stays tiny and the lifecycle
//  is clear: subscribe = create the display link, dispose = tear it down.
//
//  ── Why a private DisplayLinkProxy ───────────────────────────────────────
//
//  `CADisplayLink(target:selector:)` requires its target to be an
//  Objective-C object so it can resolve the selector by name. Rather
//  than make `PongTickEventSource` itself an `NSObject` (which leaks
//  Objective-C concerns into the public type), we extract a tiny
//  `DisplayLinkProxy: NSObject` that exists only to receive the
//  selector and forward the timestamp to a closure. The display link
//  retains the proxy; we retain the link; cleanup falls out naturally
//  from `dispose()`.
//

import MobiusCore   // EventSource, Disposable, AnonymousDisposable, Consumer
import QuartzCore   // CADisplayLink

// MARK: - PongTickEventSource

/// Drives the game loop with `tick(dt:)` events at the display refresh rate.
final class PongTickEventSource: EventSource {
	/// Every Mobius `EventSource` declares what kind of events it emits.
	typealias Event = PongEvent

	/// The active display link, or nil when not subscribed.
	private var displayLink: CADisplayLink?
	/// Timestamp of the previous fire, used to compute delta-time.
	/// Zero means "this is the first fire", so we just record it and
	/// return without emitting (no valid dt yet).
	private var lastTimestamp: CFTimeInterval = 0
	/// The closure handed to us by Mobius. We call it to push events
	/// back into the loop. nil when not subscribed.
	private var consumer: Consumer<PongEvent>?

	/// Mobius calls this when the loop starts. Job:
	///   1. Remember the consumer.
	///   2. Reset the timestamp tracker.
	///   3. Start a `CADisplayLink` (via a proxy) that fires every
	///      refresh.
	///   4. Return a `Disposable` that tears it all down.
	func subscribe(consumer: @escaping Consumer<PongEvent>) -> Disposable {
		self.consumer = consumer
		self.lastTimestamp = 0

		// The proxy is the @objc target. We forward each fire to
		// `tick(at:)`. `[weak self]` so the link's strong ref to the
		// proxy doesn't keep us alive past dispose.
		let proxy = DisplayLinkProxy { [weak self] timestamp in
			self?.tick(at: timestamp)
		}
		let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))

		// `.add(to:forMode:)` actually schedules the link. `.common`
		// means "fire even while the user is interacting with the UI"
		// (otherwise scrolling would pause the game).
		link.add(to: .main, forMode: .common)
		self.displayLink = link

		// `AnonymousDisposable` is a Mobius helper: a `Disposable` whose
		// `dispose()` runs the closure you pass.
		return AnonymousDisposable { [weak self] in
			self?.displayLink?.invalidate()  // stop the link
			self?.displayLink = nil          // drop the strong reference
			self?.consumer    = nil          // release the closure
		}
	}

	/// Testable core of the tick logic. Internal (not private) so the
	/// test target can drive it directly without needing a real
	/// CADisplayLink.
	func tick(at timestamp: CFTimeInterval) {
		// First-fire bootstrap: record the timestamp and bail. We need
		// two fires to compute a meaningful delta-time.
		if lastTimestamp == 0 {
			lastTimestamp = timestamp
			return
		}
		// Cap dt at 1/30 s. If the app was backgrounded for two seconds,
		// we don't want to integrate that as if no time passed — but we
		// also don't want a giant jump that teleports the ball off
		// screen. 1/30 is a sane upper bound (worst case: roughly two
		// frames of "lost" simulation).
		let dt = CGFloat(min(timestamp - lastTimestamp, 1.0 / 30.0))
		lastTimestamp = timestamp
		// Emit. Optional-chaining means "do nothing if we've been
		// disposed in the meantime".
		consumer?(.tick(dt: dt))
	}
}

// MARK: - DisplayLinkProxy

/// Private NSObject shim so `PongTickEventSource` itself doesn't need
/// to inherit from `NSObject`. CADisplayLink resolves the selector via
/// the Objective-C runtime, which requires the target to be an
/// `NSObject`. The proxy holds nothing but a closure and forwards each
/// fire's timestamp.
private final class DisplayLinkProxy: NSObject {
	private let onFire: (CFTimeInterval) -> Void

	init(onFire: @escaping (CFTimeInterval) -> Void) {
		self.onFire = onFire
		super.init()
	}

	@objc func fire(_ link: CADisplayLink) {
		onFire(link.timestamp)
	}
}
