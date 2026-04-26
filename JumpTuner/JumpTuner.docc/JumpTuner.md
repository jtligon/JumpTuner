# ``JumpTuner``

A tool for prototyping, previewing, and sharing platformer jump parameters.

## Overview

JumpTuner lets game designers tune the timing, height, squash & stretch, and
feel parameters of a platformer jump cycle. A robot character previews the
result in real time. Presets can be saved locally and shared as QR codes.

## Topics

### Data model

- ``JumpParams``
- ``JumpFeatures``
- ``Preset``

### Persistence

- ``PresetStore``

### Views

- ``ContentView``
- ``JumpPreviewView``
- ``ParamsEditorView``
- ``PresetsView``
- ``RobotView``
- ``HelpView``

### Shared components

- ``LabeledSlider``
- ``LabeledToggle``
- ``CollapsibleSection``
- ``ControllerButton``

### QR sharing

- ``PresetQRView``

### Theme

- ``SectionTheme``
