# Pong

A tiny iOS Pong game, built with **UIKit** and **[Spotify's
Mobius.swift](https://github.com/spotify/Mobius.swift)** — written as a
teaching artifact for **MVI** (Model-View-Intent) in Swift.

It's small enough to read in one sitting, but every piece is there for a
reason and the architecture is the kind you'd build for a real app.

> **New here?** Start with the architectural deep-dive in **[DESIGN.md](./DESIGN.md)**.
> It walks through the whole thing in ~250 lines.

---

## What it is

- **iOS / iPadOS / Designed-for-iPad-on-Mac** UIKit app, all programmatic
  (no storyboards, no nibs).
- **One human player vs. AI**, first to 7.
- Controls work via touch, keyboard (when one's connected), or both.
- Haptics on bounces and scores.

## Controls

| Action | Touch | Keyboard |
|---|---|---|
| Start / pause / resume | Tap anywhere | `Space` or `Return` |
| Move your paddle | Drag | `↑` / `↓` (or `W` / `S`) |
| Restart match (when game over) | Tap | `R` |

---

## Quick start

You need **Xcode 26.1.1+** and **macOS 26+**.

```bash
git clone https://github.com/Sajjon/pong.git
cd pong
./scripts/setup.sh        # installs just, swiftformat, swiftlint, pre-commit
just test                 # build and run the unit suite
```

Or just open `Pong.xcodeproj` in Xcode and hit ⌘R.

The `Justfile` has more recipes:

```
just test          # run tests
just cov           # tests + per-file coverage table
just cov-detailed  # tests + every uncovered line in red
just fmt           # auto-format and lint
```

CI runs the same recipes on every PR.

---

## How it's organized

```
Pong/
├── App/                            iOS lifecycle plumbing
└── Game/
    ├── PongTypes.swift             Model, Event, Effect — the vocabulary
    ├── PongLogic.swift             Pure update function (the brain)
    ├── PongEffectHandler.swift     Handles effects (haptics)
    ├── PongTickEventSource.swift   The clock (CADisplayLink)
    ├── PongScene.swift             Pure UIView — render(_ model:)
    ├── KeyboardInputMapper.swift   UIPress → PongEvent
    ├── PongGameView.swift          Wires UIKit to Mobius
    └── PongViewController.swift    Composition root (~30 LoC)
```

The single most important file is **`PongLogic.swift`** — it's a single
pure function that takes the current state plus an event, and returns
the next state plus any side effects to perform. Reading it tells you
what the game does.

For *how* it does it (and why each file exists rather than being one
giant view controller), read **[DESIGN.md](./DESIGN.md)**.

---

## A taste of the code

The whole "what does a tap mean?" decision is one function:

```swift
private static func onTap(_ model: PongModel) -> Next<PongModel, PongEffect> {
    if model.winner != nil {
        return onReset(model)        // restart
    }
    return onTogglePause(model)      // start / pause / resume
}
```

The view doesn't know any of that — it just says "the user tapped":

```swift
@objc func handleTap() {
    eventConsumer?(.tap)
}
```

That separation — **the view describes what happened, the logic decides
what it means** — is the whole point of MVI. You can read every behavior
of the game without ever opening a view file.

---

## Tests & coverage

117 tests, 98.9 % line coverage, all run in under a minute. The tests
follow a strict Arrange-Act-Assert format so each one reads top-to-bottom:

```swift
func test_onTap_withWinner_resets() {
    // Arrange
    var model = startedModel()
    model.leftScore = PongModel.winningScore

    // Act
    let next = PongLogic.update(model: model, event: .tap)

    // Assert
    XCTAssertEqual(next.model!.leftScore, 0)
}
```

To run them:

```bash
just cov
```

---

## For learners

If you're new to MVI / Mobius / UIKit-without-storyboards, this repo is
designed to be readable — every source file has a top-of-file primer
that explains what it does and how it fits into the bigger picture.
Recommended reading order:

1. **[DESIGN.md](./DESIGN.md)** — the architecture in one place
2. `Pong/Game/PongTypes.swift` — the data model
3. `Pong/Game/PongLogic.swift` — the rules of the game
4. `Pong/Game/PongTickEventSource.swift` — how external events get in
5. `Pong/Game/PongEffectHandler.swift` — how the world hears back
6. `Pong/Game/PongScene.swift` — pure rendering
7. `Pong/Game/PongGameView.swift` — the Mobius/UIKit boundary
8. `Pong/Game/PongViewController.swift` — wiring it all up

If something isn't clear, that's a documentation bug — please open an
issue.

---

## Files at the root

| File | Purpose |
|---|---|
| [`README.md`](./README.md) | This file |
| [`DESIGN.md`](./DESIGN.md) | Architecture deep-dive |
| [`CLAUDE.md`](./CLAUDE.md) | Operating manual for AI assistants |
| `Justfile` | Local task runner |
| `.github/workflows/ci.yml` | CI: typos, format, lint, test, coverage |
| `.swiftformat`, `.swiftlint.yml` | Style enforcement |
| `.pre-commit-config.yaml` | Git pre-commit hooks |
| `codecov.yml` | Coverage policy |
| `scripts/` | Setup + coverage helpers |
