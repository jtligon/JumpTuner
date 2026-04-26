# Understanding the jump cycle

How JumpTuner models a platformer jump as a sequence of named phases.

## Overview

A platformer jump is a series of distinct phases, each with its own
duration and visual transform. JumpTuner makes each phase independently tunable.

## The eight phases

| Phase | What happens | Key parameters |
|---|---|---|
| **squat** | Character crouches | `squatFrames`, `squatScale` |
| **launch** | Leaves the ground | 2 frames, `launchScale` |
| **ascent** | Rising arc | `ascentFrames`, `jumpHeight` |
| **apex** | Peak hover | `apexFrames`, `apexGravFactor` |
| **descent** | Falling arc | `descentFrames`, `fallMult` |
| **land** | Ground contact | 2 frames |
| **landing** | Impact squash | `landingFrames`, `landScale` |
| **recover** | Return to idle | 4 frames |

## Squash and stretch math

Volume is preserved by inverting the orthogonal axis:
if `scaleY = 0.7`, then `scaleX = 1/0.7 = 1.43`.

## Asymmetric gravity

Descent easing is warped via a power curve: `pow(t, 1.0 / fallMult)`.
A `fallMult` of 1.0 is linear. 2.0+ produces a snappy drop.

## Height scaling

`jumpHeight` (0-500) maps to screen pixels proportionally.
250 always means half the usable screen height on any device.
