# JumpTuner

A SwiftUI iOS app for prototyping, previewing, and sharing platformer jump feel parameters.

![iOS 16+](https://img.shields.io/badge/iOS-16%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![No dependencies](https://img.shields.io/badge/dependencies-none-green)

---

## What it does

JumpTuner gives game designers and developers a tactile way to tune the 15 numeric parameters and 7 boolean flags that define how a platformer character jumps. A character previews the jump in real time as you move sliders. Presets can be saved, loaded, and shared as QR codes.

## Features

- **SpriteKit-powered preview** — 60fps physics-accurate jump arc, rendered in a SpriteKit scene
- **Character picker** — choose from Robot, Rabbit, or Pirate; or import any photo as a custom skin
- **15 tunable parameters** — timing, height, squash & stretch, and game-feel tricks
- **7 feel toggles** — coyote time, jump buffering, variable height, asymmetric gravity, apex float, floating hover, rubber bounce
- **Stepper buttons** — `-- / - / value / + / ++` buttons on every slider for precise increments alongside coarse drag
- **Sky progress** — stars and planets accumulate in the background as your jump count grows
- **Randomize / reset** — dice button for inspiration, reset button to return to defaults
- **Loop mode** — repeat the jump cycle continuously to evaluate feel over time
- **Preset system** — name and save configurations, load or delete them
- **QR export/import** — share presets as scannable QR code images via the system share sheet
- **In-app help** — tap `?` in the drawer for a plain-English explanation of every parameter

## Requirements

- Xcode 15+
- iOS 16+ deployment target
- No third-party dependencies (CoreImage handles QR generation, SpriteKit is system-provided)

## Setup

1. Open Xcode → File → New → Project → iOS → App
2. Set Interface: **SwiftUI**, Language: **Swift**, Storage: **None**
3. Delete the template `ContentView.swift` and `<AppName>App.swift`
4. Drag all `.swift` files from this folder into the project navigator
   - Check "Copy items if needed"
   - Check your app target
5. Build and run — no additional configuration needed

## File map

| File | Responsibility |
|---|---|
| `JumpTunerApp.swift` | `@main` entry point |
| `Theme.swift` | Color constants and section accent colors |
| `Models.swift` | `JumpFeatures`, `JumpParams`, `Preset`, `SkyProgress` data structures |
| `PresetStore.swift` | JSON persistence, `ObservableObject` preset list |
| `Components.swift` | `LabeledSlider` (with stepper buttons), `LabeledToggle`, `CollapsibleSection`, `ControllerButton` |
| `JumpPhase.swift` | `JumpPhase` enum used to drive character expressions |
| `JumpPhysicsConfig.swift` | Maps `JumpParams` to concrete SpriteKit durations and scale values |
| `JumpScene.swift` | `SKScene` subclass — owns the animation loop via `SKAction` sequences |
| `JumpPreviewView.swift` | SwiftUI wrapper: `SpriteView` + play/loop controls + character picker overlay |
| `CharacterSkin.swift` | `CharacterSkin` enum (robot, rabbit, pirate, custom photo) + factory |
| `RobotNode.swift` | SpriteKit robot character node with phase-driven expressions |
| `RabbitNode.swift` | SpriteKit rabbit character node |
| `PirateNode.swift` | SpriteKit pirate character node |
| `GeneratedCharacterNode.swift` | SpriteKit node that renders a user-supplied photo as a character |
| `CharacterPhotoFlow.swift` | Photo picker sheet + image processing for custom skins |
| `RobotView.swift` | Legacy SwiftUI robot (used in Xcode previews) |
| `ParamsEditorView.swift` | All four collapsible slider/toggle sections |
| `PresetsView.swift` | Save / load / delete / QR preset UI |
| `ContentView.swift` | Root layout, side drawer, glues everything together |
| `QRHelpers.swift` | QR generation, `UIActivityViewController` share sheet, `PresetQRView` |
| `HelpView.swift` | In-app parameter reference guide |

## Adding a new parameter

1. Add the property to `JumpParams` in `Models.swift` with a default value
2. Add a `LabeledSlider` or `LabeledToggle` row in `ParamsEditorView.swift`
3. Consume the value in `JumpPhysicsConfig.swift` (derive a physics constant) and/or in `JumpScene.swift`'s `runJumpSequence()` (add or modify an `SKAction` step)
4. Add an entry to the appropriate `HelpSection` in `HelpView.swift`
5. Update `JumpParams.randomized()` if the parameter should be randomizable

The `Codable` conformance on `JumpParams` means QR serialization is automatic — new properties serialize/deserialize without any additional code.

## QR payload format

Presets are encoded as JSON:

```json
{
  "n": "My Preset",
  "d": {
    "squatFrames": 3,
    "ascentFrames": 11,
    "apexFrames": 2,
    "descentFrames": 8,
    "landingFrames": 3,
    "jumpHeight": 60,
    "squatScale": 0.7,
    "launchScale": 1.4,
    "landScale": 0.55,
    "coyoteFrames": 5,
    "bufferFrames": 4,
    "fallMult": 1.6,
    "apexGravFactor": 0.4,
    "floatFrames": 10,
    "bounceCount": 2,
    "features": {
      "coyoteTime": true,
      "jumpBuffer": true,
      "variableJump": true,
      "asymGrav": true,
      "apexGrav": true,
      "floating": false,
      "rubberBounce": false
    }
  }
}
```

Scan the QR code with any reader, copy the JSON, and paste it into the Import tab of any preset's QR panel to load it.

## Future ideas

- Camera-based QR scanning (AVFoundation) to replace paste import
- `NSPersistentCloudKitContainer` for iCloud sync if preset library grows large
- Haptic feedback on landing
- Export parameters as Swift / GDScript / C# code snippets
- Apple Watch companion for quick preset recall
