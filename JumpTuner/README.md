# JumpTuner

A SwiftUI iOS app for prototyping, previewing, and sharing platformer jump feel parameters.

![iOS 16+](https://img.shields.io/badge/iOS-16%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![No dependencies](https://img.shields.io/badge/dependencies-none-green)

---

## What it does

JumpTuner gives game designers and developers a tactile way to tune the 13 numeric parameters and 5 boolean flags that define how a platformer character jumps. A robot character previews the jump in real time as you move sliders. Presets can be saved, loaded, and shared as QR codes.

## Features

- **Full-screen animated preview** — see your jump arc immediately as you adjust sliders
- **13 tunable parameters** — timing, height, squash & stretch, and game-feel tricks
- **5 feel toggles** — coyote time, jump buffering, variable height, asymmetric gravity, apex float
- **Randomize / reset** — dice button for inspiration, reset button to return to defaults
- **Loop mode** — repeat the jump cycle continuously to evaluate feel over time
- **Preset system** — name and save configurations, load or delete them
- **QR export/import** — share presets as scannable QR code images via the system share sheet
- **In-app help** — tap `?` in the drawer for a plain-English explanation of every parameter

## Requirements

- Xcode 15+
- iOS 16+ deployment target
- No third-party dependencies (CoreImage handles QR generation)

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
| `Models.swift` | `JumpFeatures`, `JumpParams`, `Preset` data structures |
| `PresetStore.swift` | JSON persistence, `ObservableObject` preset list |
| `Components.swift` | `LabeledSlider`, `LabeledToggle`, `CollapsibleSection`, `ControllerButton` |
| `RobotView.swift` | Robot character with phase-driven arm/eye expressions |
| `JumpPreviewView.swift` | Full-screen preview, star background, 60fps animation engine |
| `ParamsEditorView.swift` | All four collapsible slider/toggle sections |
| `PresetsView.swift` | Save / load / delete / QR preset UI |
| `ContentView.swift` | Root layout, side drawer, glues everything together |
| `QRHelpers.swift` | QR generation, `UIActivityViewController` share sheet, `PresetQRView` |
| `HelpView.swift` | In-app parameter reference guide |

## Adding a new parameter

1. Add the property to `JumpParams` in `Models.swift` with a default value
2. Add a `LabeledSlider` or `LabeledToggle` row in `ParamsEditorView.swift`
3. Use the value in `JumpPreviewView.swift`'s `runCycle()` switch statement
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
    "features": {
      "coyoteTime": true,
      "jumpBuffer": true,
      "variableJump": true,
      "asymGrav": true,
      "apexGrav": true
    }
  }
}
```

Scan the QR code with any reader, copy the JSON, and paste it into the Import tab of any preset's QR panel to load it.

## Future ideas

- Camera-based QR scanning (AVFoundation) to replace paste import
- `NSPersistentCloudKitContainer` for iCloud sync if preset library grows large
- Haptic feedback on landing
- Multiple characters / skins
- Export parameters as Swift / GDScript / C# code snippets
- Apple Watch companion for quick preset recall
