# Architecture

## Overview

JumpTuner follows a straightforward SwiftUI data-flow pattern:

```
JumpParams (value type)
    ↓ @Binding
JumpPreviewView          ParamsEditorView
(reads + animates)       (reads + writes via sliders)
    ↑                         ↑
    └──────── ContentView ────┘
              @State params
              @StateObject PresetStore
```

`JumpParams` is a plain `Codable` struct — a value type. It flows down as a `@Binding` to child views. There's no view model layer; `ContentView` is the single source of truth and is small enough that this is appropriate.

---

## Data flow

### Editing parameters

1. User moves a slider in `ParamsEditorView`
2. `@Binding var params` is written through to `ContentView`'s `@State`
3. SwiftUI propagates the change to `JumpPreviewView` via its own `@Binding`
4. `JumpPreviewView.onChange(of: params)` fires
5. If animating, `restartAnimation()` kills the current `Timer` and starts a fresh cycle with the new values

### Saving a preset

1. User types a name and taps Save in `PresetsView`
2. `PresetStore.save(_:)` is called with a `Preset` snapshot of current params
3. `@Published var presets` is mutated → SwiftUI re-renders `PresetsView`
4. `persist()` writes the updated array to disk atomically

### Loading a preset

1. User taps Load on a `PresetsView` row
2. `params = preset.params` is assigned in the binding chain
3. Same propagation as editing parameters above

---

## Animation engine

The jump animation lives entirely in `JumpPreviewView.runCycle()`. Key design decisions:

### Why a Timer, not SwiftUI animation?

SwiftUI's `.animation()` and `withAnimation` are designed for UI state transitions — they interpolate between two known states. The jump cycle has 8 phases with different easing curves, squash/stretch transforms, and conditional logic (asymmetric gravity, apex float). A 60fps `Timer` with explicit per-frame math is cleaner and more controllable.

### Phase model

Each jump is a sequence of `PhaseStep` structs with a name and frame duration:

```
squat → launch → ascent → apex → descent → land → landing → recover
```

The timer computes the current phase and local `t` (0–1 within that phase) on every tick, then applies the appropriate transform via a `switch` statement.

### Squash & stretch math

Volume preservation is approximated by inverting the orthogonal axis:
- If `scaleY = 0.7`, then `scaleX = 1/0.7 ≈ 1.43`
- This keeps the character's visual "mass" constant through deformation

### Asymmetric gravity

Instead of changing the actual physics, we warp the easing curve:
```swift
let de = pow(t, 1 / fallMult)
```
`fallMult = 1.0` → linear (symmetric). `fallMult = 2.0` → falls quickly then slows near the ground. This produces the feel of stronger gravity without changing the descent frame count.

### Height scaling

`jumpHeight` is a 0–500 value mapped to screen pixels:
```swift
scaledHeight = (jumpHeight / 500.0) * (screenHeight - groundClearance)
```
This ensures presets look consistent across device sizes — a value of 250 always means "half the usable screen height."

---

## Persistence

`PresetStore` writes a JSON array to `Documents/jump_presets.json`. Relevant decisions:

- **Atomic writes** (`options: .atomic`) — the OS writes to a temp file, then renames. A crash mid-write never corrupts the existing file.
- **`Codable` on `JumpParams`** — adding new parameters to the struct is automatically backward-compatible for new saves. Old saves without the new key will decode using the property's default value.
- **No Core Data** — a flat JSON file is appropriate for a list of small structs with no relational queries. Core Data would add schema migration overhead with no benefit at this scale.

---

## QR sharing

QR codes are generated entirely on-device using `CIFilter.qrCodeGenerator()` from `CoreImage` — no network call, no third-party library.

The payload is the full `JumpParams` JSON wrapped with the preset name:
```json
{ "n": "Preset name", "d": { ...JumpParams... } }
```

The `Codable` conformance means adding new parameters to `JumpParams` automatically updates the QR payload format.

**Import path:** Currently paste-based (scan with system camera → copy JSON → paste into Import tab). A future `AVFoundation` QR scanner view would replace this.

---

## Adding a new feel parameter

1. **`Models.swift`** — add property with default to `JumpParams`
2. **`ParamsEditorView.swift`** — add `LabeledSlider` or `LabeledToggle`
3. **`JumpPreviewView.swift`** — use the value in `runCycle()`'s switch
4. **`HelpView.swift`** — add a `HelpItem` to the appropriate section
5. **`Models.swift`** — add to `randomized()` if applicable

`Codable` handles QR serialization automatically. `PresetStore` handles persistence automatically. No other files need to change.
