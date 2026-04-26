# DESIGN.md

How Pong is put together, and *why* — the design decisions that aren't
obvious from reading the code.

If you only read one thing in this repo, read this.

---

## 1. The MVI loop, in one diagram

```
   ┌──────────────────────────────────────────────────────────────────┐
   │                                                                  │
   │                      ┌────────────────────┐                      │
   │       Event ───────► │  PongLogic.update  │ ───► Next(Model,     │
   │     (raw input,      │   (pure function)  │           [Effect])  │
   │   tick, viewport,    └────────────────────┘                      │
   │       lifecycle)              ▲   │                              │
   │           ▲                   │   │ Model                        │
   │           │                   │   ▼                              │
   │           │                ┌─────────────┐                       │
   │           │                │ MobiusLoop  │                       │
   │           │                └─────────────┘                       │
   │           │                   │   │                              │
   │           │              Event│   │Effect                        │
   │           │                   │   ▼                              │
   │  ┌────────┴─────────┐   ┌──────────────────┐                     │
   │  │   PongGameView   │   │ PongEffectHandler │  haptics, sound   │
   │  │  (Connectable)   │   │   (Connectable)   │      …            │
   │  └──────────────────┘   └──────────────────┘                     │
   │           ▲                                                      │
   │           │ Model                                                │
   │           │                                                      │
   │  ┌────────┴────────┐                                             │
   │  │   PongScene     │ pure UIView, render(_ model:)               │
   │  └─────────────────┘                                             │
   │                                                                  │
   └──────────────────────────────────────────────────────────────────┘
```

Three rules govern everything in this repo:

1. **The model only changes inside `update`.** Nothing else mutates state.
2. **Side effects only happen inside the effect handler.** `update` is pure.
3. **The view is a function of the model.** `render(_ model:)` only reads.

That's it. Every other decision in the project follows from these three.

---

## 2. The Mobius vocabulary (cheat-sheet)

| Term | What it is | Where in this repo |
|---|---|---|
| **Model** | The entire game state at one instant | `PongModel` (`PongTypes.swift`) |
| **Event** | Something that happened (input, tick, …) | `PongEvent` |
| **Effect** | A request from logic to the outside world | `PongEffect` |
| **Update** | Pure function `(Model, Event) → (Model, [Effect])` | `PongLogic.update` |
| **Initiate** | Pure function `Model → First<Model, Effect>` | `PongLogic.initiate` |
| **Connectable** | An adapter between the loop and the world | `PongGameView`, `PongEffectHandler` |
| **EventSource** | An object that produces events on its own schedule | `PongTickEventSource` |
| **Connection** | The handle the loop hands a Connectable on connect | returned by `connect(_:)` |
| **Consumer** | A `(T) -> Void` closure for pushing values | param to `connect`/`subscribe` |

If a term in the codebase isn't on this list, it's an iOS/Swift concept,
not a Mobius one.

---

## 3. File map (what lives where, and why)

```
Pong/
├── App/
│   ├── AppDelegate.swift            App-process boot
│   ├── SceneDelegate.swift          Per-window boot, installs PongViewController
│   └── Info.plist                   UILaunchScreen + scene manifest
├── Game/
│   ├── PongTypes.swift              Model + Event + Effect (the vocabulary)
│   ├── PongLogic.swift              initiate + update + on<Event> handlers
│   ├── PongEffectHandler.swift      Connectable<Effect, Event> — haptics
│   ├── PongTickEventSource.swift    EventSource — CADisplayLink → .tick
│   ├── PongScene.swift              Pure UIView. One method: render(_:)
│   ├── KeyboardInputMapper.swift    Translates UIPress → PongEvent
│   ├── PongGameView.swift           Connectable<Model, Event> — touch + composition
│   └── PongViewController.swift     Composition root, ~30 LoC
└── Assets.xcassets/                 App icon + accent color
```

Tests mirror this layout under `PongTests/`.

---

## 4. The eight-event grammar

`PongEvent` has exactly these cases — the entire surface area of "things
that can drive a state change":

| Event | Source | What `update` does |
|---|---|---|
| `.tick(dt:)` | `PongTickEventSource` (CADisplayLink) | Advance physics |
| `.tap` | `PongGameView.handleTap` | If winner, reset; else togglePause |
| `.dragTo(y:)` | `PongGameView.handlePan` | Compute paddle direction from y |
| `.dragEnded` | `PongGameView.handlePan` | Stop the player paddle |
| `.playerInput(.up/.down/.stop)` | `KeyboardInputMapper` | Set paddle velocity |
| `.viewportChanged(CGSize)` | `PongGameView.layoutSubviews` | Resize court, rescale positions |
| `.reset` | Keyboard `R` | Fresh model, scores ← 0 |
| `.togglePause` | Keyboard `Space`/`Return` | Flip `isPaused` |

Notice what's *not* there: `.scoreLeft`, `.bounceTopWall`, `.aiMove`. Those
are *consequences* of `.tick`, computed inside `onTick`, not events. Events
describe inputs to the system; the simulation itself isn't an input.

---

## 5. Decisions we made and why

### 5.1 No "ViewModel" type

In MVVM you'd have a `PongViewModel` observed by the view. We don't. In
Mobius, **the Model is the view model** — the single source of truth that
the pure update function transforms. Adding a separate VM would mean two
places hold state, and you'd have to keep them in sync. That's exactly the
bug class MVI exists to prevent.

If derived display values need names, add **computed properties on
`PongModel`** (we already do this with `winner`).

### 5.2 No `PongModelSnapshot` for the view

Earlier the view cached `currentModel: PongModel?` so gesture handlers
could read `winner` and `leftPaddle.center.y` synchronously. The smell
wasn't the cache — it was that **the view was making domain decisions**.

The fix was to push the decisions into `update`:
- `handleTap()` became `eventConsumer?(.tap)` (one line, no cache)
- `onTap(model:)` in `PongLogic` decides reset vs. togglePause based on
  `model.winner`

The snapshot disappeared. The view is now genuinely stateless w.r.t. the
domain. **A `PongModelSnapshot` projection type would have been the wrong
fix** — it would have preserved the smell while adding ceremony.

### 5.3 Scene/GameView split

`PongGameView` used to be ~270 LoC doing four jobs: subview setup, render,
keyboard, touch, Mobius wiring. We split it into:

- **`PongScene`** (UIView): pure render. One public method: `render(_:)`.
- **`KeyboardInputMapper`**: owns `heldKeys` (a tiny state machine), takes
  a dispatch closure at init.
- **`PongGameView`** (UIView, Connectable): composes the two, owns touch
  input, owns the connection port (`eventConsumer`).

Coordination overhead is one closure (`KeyboardInputMapper.init(dispatch:)`)
and one method call (`scene.render(model)`). No protocols, no delegates.

### 5.4 The connection port is mutable, on purpose

`PongGameView.eventConsumer: Consumer<PongEvent>?` is the only mutable
property left. Mobius's `Connectable` lifecycle is **`nil → consumer →
nil`** — the consumer is handed in via `connect(_:)` and must be nilled
out in the dispose closure (otherwise the view emits into a torn-down
loop). It's not "state"; it's a port whose identity changes with the
connection lifecycle.

### 5.5 `PongTickEventSource` extracts a `DisplayLinkProxy`

`CADisplayLink(target:selector:)` requires an `NSObject` target. Rather
than make the public type an `NSObject` (leaking Objective-C concerns into
its surface), a private `DisplayLinkProxy: NSObject` at the bottom of the
file holds the `@objc fire(_:)` selector and forwards to a closure. The
public type is a plain Swift class.

### 5.6 `PongEffectHandler` doesn't store the haptic generators

`UIFeedbackGenerator` is `@MainActor`. Storing instances as `let`
properties caused a heap-corruption abort during the handler's deinit
(deinits run on whatever executor releases the last ref; a non-main
executor releasing MainActor properties trips libmalloc).

Fix: construct generators **inside** the `DispatchQueue.main.async`
closure in `connect`'s `acceptClosure`. They're born, used, and released
on main. The marginal cost of constructing a generator per haptic is
negligible.

### 5.7 No actor-isolation noise

Earlier the project had:

```
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
```

…which forced an implicit `@MainActor` onto every type. That meant Mobius
crossing its serial queue with our model/event/effect required
`nonisolated` annotations everywhere, plus the deinit-crash issue above.

We removed both flags. The codebase now reads as plain Swift 5: no
`nonisolated`, no explicit `@MainActor`. UI types still get MainActor —
they inherit it from `UIView` / `UIViewController` / `UIResponder` (which
UIKit declares `@MainActor`).

---

## 6. Concurrency model

- **Mobius's loop runs on its own internal serial queue.** Logic, effect
  handler `accept`, and event source `subscribe` are called from that
  queue, not main.
- **The view connection runs on main.** Mobius posts model deliveries to
  the main queue when the Connectable is a UIView.
- **UI work happens on main.** `PongScene.render` is called from
  Mobius's main-queue delivery; `PongEffectHandler` explicitly hops to
  main inside its accept closure (because effects are dispatched on the
  loop's queue, not main).
- **The display link fires on main.** `CADisplayLink.add(to: .main, …)`
  guarantees this.

You should never have to think about threads in this codebase. If you do,
you're probably about to add `nonisolated`/`@MainActor` — don't. Look at
where the boundary is and put a `DispatchQueue.main.async` there instead.

---

## 7. Test strategy

- **`PongLogic` is the most-tested file** because it's where every
  behavior lives. It has 100 % line coverage and exhaustive case-by-case
  tests in `PongLogicTests.swift`.
- **Pure value types** (`PongModel`, `PongEvent`, `PongEffect`) get
  trivial Equatable / round-trip tests.
- **UIKit-adjacent types** (`PongScene`, `PongGameView`,
  `PongViewController`) get smoke-tests via `XCTAssertNoThrow` plus
  outcome assertions on the events they emit.
- **Tests use AAA with strict line caps.** See `CLAUDE.md` for the rules.
- **Project-wide coverage target: ≥ 98 %.** Currently 98.9 %. Codecov
  enforces no-regression on PRs.

---

## 8. Anti-patterns we deliberately reject

| Pattern | Why we don't | What we do instead |
|---|---|---|
| Separate `ViewModel` class | Splits state | Computed properties on `PongModel` |
| `PongModelSnapshot` projection | Preserves the smell | Push the decision into `update` |
| `currentModel` cache in the view | View shouldn't decide | View emits raw events |
| `nonisolated` on every type | Symptom, not cause | Remove the build setting |
| `@MainActor` on every UI type | Already inherited | Don't annotate |
| Storing `UIFeedbackGenerator` props | Crashes on off-main deinit | Construct inside main-queue closure |
| Big view controller | Hides distinct concerns | Extract Scene, Mapper, EventSource |

---

## 9. Where to add things

| New thing | Goes where |
|---|---|
| New game rule (e.g. "speed up after 5 hits") | New helper in `PongLogic`, called from `onTick` |
| New input gesture | `PongGameView.setupGestures` + new `PongEvent` case + `onWhatever` in logic |
| New side effect (e.g. sound) | New `PongEffect` case + new branch in `PongEffectHandler` |
| New external trigger (e.g. game-center event) | New `EventSource` + `.withEventSource(...)` in `PongViewController` |
| New display element (e.g. timer) | Subview of `PongScene` + read from new `PongModel` field in `render` |

If the answer doesn't match one of these, you're probably designing
something the architecture doesn't currently support — pause and re-read
this doc before shoehorning it in.
