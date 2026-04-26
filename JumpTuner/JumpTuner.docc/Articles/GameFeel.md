# The five feel tricks

Boolean toggles that make platformer jumping feel responsive to player intent.

## Overview

Raw physics define the arc. The five feel tricks define how it responds
to input. Together they are the difference between mechanical and great.

## Coyote time

Lets the player jump for a few frames after walking off a ledge.
4-6 frames is invisible but dramatically reduces frustration.

## Jump buffering

Remembers a jump pressed just before landing and fires it on ground contact.
Makes rapid repeated jumping feel snappy rather than requiring precise timing.

## Variable jump height

Releasing jump early cuts upward velocity. Holding through the apex yields
full height. The single most impactful feel improvement in a platformer.

## Asymmetric gravity

Gravity pulls harder during descent (fallMult controls the strength).
Keeps pace up while preserving hang time at the apex.

## Apex gravity reduction

Reduces gravity at the jump peak, creating a float window for aiming
landings. Works best with 1-3 apex float frames.
