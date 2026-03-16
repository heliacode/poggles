# Poggles — Arcade Visual Effects Specification (Godot)

## Purpose

This document describes the visual feedback and effects system required for the game **Poggles**, implemented in **Godot**.

The goal is to create a high-energy arcade feel inspired by the neon particle aesthetic of **Geometry Wars: Retro Evolved**.

Gameplay actions must produce strong visual feedback, including particles, glow, pulsing effects, and camera reactions.

The visual language should feel:

- energetic
- reactive
- neon-arcade
- readable under chaos
- satisfying to interact with

---

## Core Visual Principles

### 1. Hit Feedback Must Over-Respond

Whenever a meaningful gameplay interaction occurs (enemy hit, destruction, collision), the game should over-respond visually.

Every hit should include some combination of:

- particle burst
- brief flash
- scale pop
- sound spike
- optional camera shake

The visual feedback should feel bigger than the underlying mechanic.

Example interactions that trigger feedback:

- enemy destroyed
- player hit
- object collision
- special ability activation

---

## Visual Systems To Implement

### 1. Particle Effects

Use **GPUParticles2D** for particle systems.

Particles are used for:

- explosions
- enemy deaths
- projectile trails
- score pickups
- sparks
- environmental energy effects

Recommended particle properties:

```txt
lifetime: 0.15 – 1.2 seconds
velocity: random radial
size: decreasing over time
alpha: fading
color: neon palette
```

#### Enemy Death Example

Enemy death should produce:

- radial burst of particles
- bright color matching enemy
- particles fade quickly
- optional additive glow

---

### 2. Additive Blending

Particle systems and glow effects should use additive blending.

Concept:

```txt
final_color = base_color + particle_color
```

This causes overlapping particles to increase brightness instead of darkening.

Apply additive blending to:

- explosions
- bullet trails
- sparks
- glow effects

Godot implementation:

Use **CanvasItemMaterial** with additive blending.

---

### 3. Bloom / Glow

Implement bloom so bright objects glow outward.

Bloom should apply to:

- enemies
- bullets
- explosions
- pickups
- energy objects
- optional grid background

Example bloom parameters:

```txt
bloomThreshold: 0.7
bloomIntensity: 1.5
bloomRadius: medium
```

Important:

Glow should be applied only to bright elements, not the entire scene.

---

### 4. Pulsing / Oscillation

Objects should subtly pulse to feel alive.

Use sine-based oscillation.

Concept:

```txt
brightness = base + sin(time * frequency) * amplitude
```

Apply pulsing to:

- enemies
- pickups
- energy props
- optional grid background

Recommended values:

```txt
frequency: 2–6 Hz
amplitude: 5–20%
```

Avoid exaggerated motion. Pulsing should feel electrical and subtle.

---

### 5. Camera Shake

Camera shake adds physical impact.

Use small shakes triggered by events:

- explosions
- player damage
- powerful enemy death
- special abilities

Example parameters:

```txt
shakeIntensity: small to medium
shakeDuration: 0.1 – 0.4 seconds
shakeDecay: exponential
```

Godot implementation:

Modify:

```txt
Camera2D.offset
```

---

### 6. Neon Color Palette

The game should use a high-contrast neon palette.

Background:

```txt
deep black or very dark navy
```

Primary colors:

```txt
electric blue
neon pink
cyan
bright green
orange
yellow
```

Design rule:

- gameplay objects = bright
- background = dark

This maximizes glow visibility.

---

### 7. Visual Timing Rules

Arcade feedback must be:

- immediate
- strong
- short

Effects should start on the exact frame of interaction whenever possible.

Avoid:

- slow cinematic fades
- long particle lifetimes
- heavy visual clutter

Most particle bursts should last:

```txt
0.15 – 0.6 seconds
```

---

## Optional Enhancement — Energy Grid

An optional glowing grid background can reinforce the arcade aesthetic.

Grid properties:

- subtle glow
- slow brightness pulse
- reacts slightly to explosions

Example pulse:

```txt
grid_brightness = base + sin(time * slow_frequency)
```

---

## Godot Implementation Preferences

Use the following systems where appropriate.

Particles:

```txt
GPUParticles2D
```

Glow and blending:

```txt
CanvasItemMaterial
additive blending
```

Camera effects:

```txt
Camera2D.offset
```

Brightness pulsing:

```txt
self_modulate
modulate
or shader parameters
```

---

## Design Goal

The final Poggles visual experience should feel:

- reactive
- glowing
- energetic
- arcade-style
- satisfying to play

During intense moments the screen should fill with:

- particles
- neon light
- motion

But gameplay readability must always remain clear.
