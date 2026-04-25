//
//  PongTickEventSource.swift
//  Pong
//
//  Created by Alexander Cyon on 2026-04-23.
//

import MobiusCore
import QuartzCore

nonisolated final class PongTickEventSource: NSObject, EventSource {
	typealias Event = PongEvent

	private var displayLink: CADisplayLink?
	private var lastTimestamp: CFTimeInterval = 0
	private var consumer: Consumer<PongEvent>?

	func subscribe(consumer: @escaping Consumer<PongEvent>) -> Disposable {
		self.consumer = consumer
		self.lastTimestamp = 0
		let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
		link.add(to: .main, forMode: .common)
		self.displayLink = link
		return AnonymousDisposable { [weak self] in
			self?.displayLink?.invalidate()
			self?.displayLink = nil
			self?.consumer = nil
		}
	}

	@objc private func tick(_ link: CADisplayLink) {
		if lastTimestamp == 0 {
			lastTimestamp = link.timestamp
			return
		}
		let dt = CGFloat(min(link.timestamp - lastTimestamp, 1.0 / 30.0))
		lastTimestamp = link.timestamp
		consumer?(.tick(dt: dt))
	}
}
