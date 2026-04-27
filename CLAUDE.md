# CLAUDE.md

Instructions for the AI assistant working on this repo. Treat this file as a
short operating manual — read it before touching anything.

## Read DESIGN.md first

Before making non-trivial changes, read **[`DESIGN.md`](./DESIGN.md)**. The
architecture is small but opinionated; if you skip the design doc you will
likely re-introduce one of the patterns we deliberately removed (separate
ViewModel, MainActor-default isolation, model snapshot type, decisions in
the view…).

## What this project is

A UIKit Pong game built on **Spotify's Mobius.swift** as a pure-MVI teaching
artifact. The pure logic lives in `PongLogic`; the view is a thin
`Connectable` over a render-only `PongScene`; per-frame ticks are produced
by an `EventSource` (`PongTickEventSource`); haptics are `Effect`s. Plain
Swift 5 — no actor-isolation noise.

## Tooling: LSP first, text tools last

This project is Swift. **Use the Swift LSP plugin** at
`~/.claude/plugins/marketplaces/claude-plugins-official/plugins/swift-lsp/`
before reaching for `Bash`, `grep`, `sed`, `awk`, `find`, or `xcodebuild`.
The LSP tools are deferred — at the start of every session, run:

```
ToolSearch(query: "select:LSP")
```

The `swift-lsp-first` skill auto-surfaces on Swift work and has the full
substitution table. The short version:

| When you want to… | Use LSP | Not |
|---|---|---|
| See a symbol's signature | hover | `Read` of the source |
| Find call sites | references | `grep -rn` |
| Find a symbol by name | workspace symbol | `find` + `grep` |
| Verify a change compiles | diagnostics | `xcodebuild build` |
| Rename a symbol | rename | `sed -i` / `Edit replace_all` |
| Bulk-strip a keyword | rename / code action | `sed` |

Reserve `xcodebuild` for what only it does: full-target compilation,
running the test suite (`just test`), and coverage (`just cov`). Never use
it as a syntax checker — that's the LSP's job, and it answers in
milliseconds instead of 30+ seconds.

Reserve `sed` / `awk` / `grep` for genuinely text-level files: markdown,
plists, YAML, shell scripts, log inspection. They have no place
modifying `.swift` source — they can't tell code from comments or string
literals, and `sed -i` corrupts files silently when matches land in
unintended places. The LSP works at the AST level and won't.

## Commands

| Goal | Command |
|---|---|
| Run unit tests | `just test` |
| Run tests + per-file coverage table | `just cov` |
| Run tests + show every uncovered line in red | `just cov-detailed` |
| Format + lint with the same rules CI uses | `just fmt` |
| First-time setup (brew + pre-commit) | `./scripts/setup.sh` |

CI runs the same recipes on macOS — keep them green.

## Coverage

Project-wide line coverage must stay **≥ 98 %**. Running `just cov` prints a
per-file table; if your change drops a file below 100 %, add tests in
`PongTests/<mirroring path>/<Foo>Tests.swift`.

## Test conventions

XCTest, **strict AAA** with hard line caps. Match the existing style:

```swift
func test_thingUnderTest_state_expectedOutcome() {
    // Arrange  ← 1–4 lines max
    let model = startedModel()

    // Act      ← 1–2 lines max
    let next = PongLogic.update(model: model, event: .tap)

    // Assert   ← 1–2 lines max
    XCTAssertTrue(next.model!.isPaused)
}
```

When the act and assert collapse to a single expression, omit comments and
write the test on one line:

```swift
func test_side_left_doesNotEqualRight() {
    XCTAssertNotEqual(Side.left, .right)
}
```

## Hard rules (do not break)

1. **Decisions live in `PongLogic`.** The view emits raw events
   (`.tap`, `.dragTo(y:)`); the logic decides what they mean. If you find
   yourself reading `model` from the view to decide *what to dispatch*,
   stop — push the decision into `update`.
2. **No "ViewModel".** Mobius's `Model` is the view model. Adding a
   separate observable VM splits state into two places and breaks MVI's
   single-source-of-truth guarantee.
3. **No `nonisolated` / `@MainActor` annotations on our own types.** The
   build settings deliberately leave default isolation off; UI types
   inherit MainActor from `UIView`/`UIViewController`/`UIResponder`. Do not
   re-introduce `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` or
   `SWIFT_APPROACHABLE_CONCURRENCY = YES` to the pbxproj.
4. **The view controller stays tiny.** Currently ~30 LoC. If you're about
   to grow it, the new concern probably belongs in its own object (look
   at `PongScene`, `KeyboardInputMapper`, `PongTickEventSource` for the
   pattern).
5. **Do not store `UIFeedbackGenerator` as a property.** Construct inside
   `DispatchQueue.main.async` in `PongEffectHandler.connect`. See
   `PongEffectHandler.swift` for why.

## File-creation rules

- One type per file in `Pong/Game/` (the `DisplayLinkProxy` shim in
  `PongTickEventSource.swift` is the only exception, and it's `private`).
- Mirror the source path in `PongTests/`: `Pong/Game/Foo.swift` →
  `PongTests/Game/FooTests.swift`.
- Indentation is **tabs**, max line length 120. `swiftformat` will fix it
  for you (`just fmt`).

## Surprises you may hit

- **SourceKit "No such module 'MobiusCore' / 'UIKit'" diagnostics** are
  Xcode's stale-index noise after writes. Ignore them; trust `just test`.
- **Tests run against a host app**, so the simulator must launch
  `Pong.app`. If launch fails, check `~/Library/Logs/DiagnosticReports/`
  for a Pong-*.ips crash log — the most common culprit is touching a
  `UIFeedbackGenerator` off-main.
- **The display link proxy** is intentional. CADisplayLink needs an
  `NSObject` target; the proxy keeps `PongTickEventSource` itself a plain
  Swift class.
