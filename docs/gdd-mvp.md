# MAELSTROM'S END - MVP
## Minimum Viable Product Design Document

---

## High Concept

A simplified roguelike where you captain a pirate ship trapped in a whirlpool. Place tiles around a circular route to generate Wind while racing against the sea's pull. Escape before the whirlpool drags you down.

---

## Core Game Loop (30-60 second proof of concept)

### The One Rule That Matters
**You have two meters racing against each other:**
- **HOLD** (Red): The whirlpool pulling you down. Reaches 100 = Game Over
- **WIND** (Blue): Your escape force. Reaches 100 = Victory

### How It Works
1. Your ship auto-sails a circular loop (takes ~5-10 seconds per loop)
2. Each loop, HOLD increases by +10 automatically
3. You place tiles on the loop path to generate WIND
4. Simple waves occasionally destroy tiles (15% chance per loop)
5. First meter to 100 wins

---

## MVP Tiles (Only 4)

### 1. TRADE WIND
- **Effect**: +5 Wind when ship passes
- **Cost**: Nothing
- **Strategy**: Safe, reliable Wind generation

### 2. STORM
- **Effect**: +15 Wind when ship passes
- **Risk**: +5 Hold per loop (dangerous waters)
- **Strategy**: High risk, high reward

### 3. CALM WATER
- **Effect**: -3 Hold gain this loop
- **Cost**: Generates 0 Wind
- **Strategy**: Buys you time but doesn't help escape

### 4. WRECKAGE
- **Effect**: +3 Wind when passed
- **Risk**: +2 Hold per loop (treasure weighs you down)
- **Strategy**: Small gains with small penalty

---

## Wave Events (Keep it Simple)

**When**: 15% chance each loop
**Effect**: Destroys 1 random tile
**Visual**: Quick wave animation across the loop

That's it. No complex wave mechanics, no defense tiles, no wave types.

---

## Controls & UI

### Controls
- **Click tile from hand** → **Click empty spot on loop** = Place tile
- That's the only control

### Essential UI
1. **Two Big Meters** (top of screen)
   - HOLD: 0-100 (red bar)
   - WIND: 0-100 (blue bar)

2. **The Loop** (center screen)
   - Circular path with ~12-16 tile spots
   - Ship visibly sailing around it

3. **Tile Hand** (bottom of screen)
   - Shows 3 tiles you can place
   - Refreshes with 3 new tiles each loop

---

## Visual Requirements (Minimal)

### Must Have
- Circle path (can be simple lines)
- Ship sprite (can be a triangle)
- 4 tile icons (distinct shapes/colors)
- Two meter bars
- Wave animation (can be simple screen flash + tile removal)

### Nice to Have (Post-MVP)
- Ship rotation as it moves
- Whirlpool spiral in center
- Particle effects for Wind generation

---

## Technical Implementation

### Core Systems Needed
1. **Loop System**
   - Ship position update
   - Tile trigger when ship passes
   - Loop completion detection

2. **Meter System**
   - Hold increases each loop
   - Wind accumulation from tiles
   - Win/loss condition check

3. **Tile System**
   - Place tile on empty spot
   - Trigger effect when ship passes
   - Remove tile on wave event

4. **Wave System**
   - Random roll each loop (15% chance)
   - Pick random tile and destroy
   - Visual feedback

---

## Development Priorities

### Day 1: Core Loop (4-6 hours)
1. Ship moving in circle
2. Hold/Wind meters working
3. Basic tile placement
4. Win/loss conditions

### Day 2: Polish (2-4 hours)
1. Wave events
2. Visual feedback
3. Sound effects (if time)
4. Balance testing

---

## Success Criteria for MVP

✓ Player can place tiles
✓ Ship auto-sails the loop
✓ Meters increase/decrease properly
✓ Clear win condition (Wind = 100)
✓ Clear loss condition (Hold = 100)
✓ Waves create tension
✓ Game takes 2-3 minutes to complete
✓ Player feels the "racing meters" tension

---

## What We're NOT Building (Yet)

- NO progression between runs
- NO resource management
- NO complex tile synergies
- NO shops or upgrades
- NO multiple ship types
- NO difficulty modes
- NO combat system
- NO adjacent tile bonuses
- NO save system

---

## Post-MVP Expansion Path

If MVP is successful, add in this order:
1. 2-3 more tile types
2. Simple tile synergies (adjacent bonuses)
3. Wave warning system
4. Basic combat with enemies
5. Meta-progression (unlock new tiles)

---

## Key Metrics to Track

- Average game length (target: 2-3 minutes)
- Win rate (target: 30-40% for new players)
- Most placed tile (helps identify balance issues)
- Average loops to complete (target: 10-15)

---

**Document Version**: MVP 1.0
**Scope**: 2-day prototype
**Focus**: Core loop validation only
