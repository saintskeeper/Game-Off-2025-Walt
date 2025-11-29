# MAELSTROM'S END
## Game Design Document

---

## High Concept

A Loop Hero-inspired roguelike where you captain a pirate ship trapped in a deadly whirlpool. Build your ship's strength by strategically placing tiles around a circular route while racing against the sea's pull. Escape before the whirlpool drags you into the abyss.

---

## Core Design Pillars

- **Tension Through Inevitability**: The whirlpool always pulls you closer. Every decision is made under time pressure.
- **Risk vs. Reward**: Aggressive tile placement gives more Wind but increases Hold. Safe plays keep you alive longer but may not let you escape in time.
- **Strategic Auto-Battler**: Like Loop Hero, your ship auto-sails the route while you focus on tactical tile placement and resource management.
- **Nautical Atmosphere**: Every element reinforces the desperate maritime theme of a doomed ship fighting for survival.

---

## Core Mechanics

### The Loop

- Your pirate ship automatically sails a circular route around the whirlpool
- The route never changes - you sail the same path each loop
- Each complete loop takes approximately 30-60 seconds (adjustable)
- Tiles you place remain on the route permanently (until destroyed by waves)

### The Two Opposing Forces

**HOLD (Whirlpool's Grip)**
- Represents the sea's pull dragging you toward the center
- Starts at 0, increases by +5-10 each loop completion
- When Hold ≥ 100, you are pulled into the vortex → Game Over
- Visual representation: The loop path darkens/tightens, whirlpool center glows more intensely

**WIND (Escape Force)**
- Represents favorable winds pushing you toward freedom
- Generated through tile placement, enemy kills, and tile synergies
- When Wind ≥ 100, you break free from the whirlpool → Victory
- Visual representation: Ship's sails fill up, wind gauge on UI

### Win/Loss Conditions

**Victory**: Accumulate 100 Wind before Hold reaches 100
**Defeat**: Hold reaches 100 before you gather enough Wind

The tension is simple: **You're racing two meters against each other.**

### Wave Events

Waves are the primary danger mechanic that disrupts your strategy:

**Wave Triggers:**
- Random chance each loop (base 15% chance)
- Increased chance based on certain tiles (Storms add +10% per Storm)
- Guaranteed waves at certain Hold thresholds (Hold 50, Hold 75)

**Wave Effects:**
- **Hold Surge**: Instantly adds +15-25 Hold (massive setback)
- **Tile Destruction**: Destroys 1-3 random tiles on your route
- **Wind Loss**: Reduces current Wind by 10-15
- **Ship Damage**: Damages your ship's hull (affects combat effectiveness)

**Wave Defense:**
- Some tiles can block or redirect waves (Breakwater, Coral Reef)
- Defensive positioning can minimize wave damage
- Risk/Reward: Do you invest in wave defense or rush for Wind?

---

## Core Tiles

### WRECKAGE (Treasure/Resource)
**Function**: Spawns loot when passed
**Drops**: Supplies, cannonballs, rum, ship parts
**Hold Penalty**: +1 Hold gain per loop (each Wreckage tile)
**Strategy**: Greed weighs you down - treasure slows your escape
**Adjacency Bonus**: 3+ Wreckages unlock rare loot pool (legendary items, major ship upgrades)

### REEF (Enemy Spawner)
**Function**: Spawns hostile sea creatures
**Enemies**: Crabs, sirens, reef sharks, sea serpents
**Reward**: Enemies drop small Wind (+1-2) and resources
**Hold Impact**: Neutral
**Adjacency**: Reef + Reef = stronger enemies with better drops

### TRADE WIND (Wind Generator)
**Function**: Passive Wind generation
**Effect**: +3 Wind per loop when passed
**Hold Impact**: Neutral
**Strategy**: The "clean" wind source - no downsides
**Adjacency**: Trade Wind + Open Water = +2 bonus Wind

### STORM (High Risk/Reward)
**Function**: Spawns dangerous enemies AND increases wave chance
**Enemies**: Storm elementals, lightning spirits, waterspouts
**Reward**: Big Wind drops (+8-10) from defeated enemies
**Hold Penalty**: +3 Hold per loop
**Wave Risk**: Each Storm adds +10% wave chance
**Strategy**: High-risk power spike - can accelerate escape but invites disaster

### CALM WATERS (Defensive)
**Function**: Reduces whirlpool's pull
**Effect**: -2 Hold gain per loop when passed
**Trade-off**: Generates 0 Wind (becalmed)
**Strategy**: Buy time but doesn't help you escape
**Best Use**: Stabilize when Hold is climbing too fast

### BREAKWATER (Wave Defense)
**Function**: Protects against wave damage
**Effect**: Has 3 "durability" - absorbs 3 wave hits before breaking
**Hold Impact**: +1 Hold per loop (heavy structure)
**Strategy**: Insurance policy against catastrophic wave damage
**Placement**: Should be placed before valuable tiles you want to protect

---

## Advanced Tiles (Unlockable)

### ISLAND (Roadside Tile)
**Placement**: Adjacent to path, NOT on the path itself
**Function**: Shop/upgrade station between loops
**Services**: Buy items, repair ship, unlock abilities
**Adjacency**: 2+ Islands = quest chains unlock (special missions for rewards)

### WHIRLPOOL SHRINE
**Function**: Sacrifice resources for Wind bursts
**Cost**: Rum + Supplies
**Effect**: Instant +10-15 Wind
**Hold Impact**: +2 Hold per loop (drawing power from the maelstrom)
**Risk**: Expensive but can provide critical Wind when needed

### MERCHANT SHIP
**Function**: Trading post
**Effect**: Convert resources into better resources or Wind
**Spawn**: Neutral merchant appears, offers trades
**Hold Impact**: +1 Hold per loop

### GHOST SHIP
**Function**: High-risk combat encounter
**Effect**: Spawns powerful ghost captain enemy
**Reward**: Massive Wind drop (+20) and legendary loot
**Hold Impact**: +5 Hold per loop (cursed waters)
**Wave Risk**: +20% wave chance

### LIGHTHOUSE
**Function**: Navigation aid
**Effect**: Reveals upcoming wave warnings 1 loop in advance
**Bonus**: +1 Wind per loop
**Adjacency**: Lighthouse + Trade Wind = double wind bonus

### ANCIENT ANCHOR
**Function**: Emergency brake
**Effect**: Freezes Hold gain for 2 loops (one-time use, then tile breaks)
**Hold Impact**: None while active
**Strategy**: Panic button when Hold is spiraling out of control

---

## Resource System

### Primary Resources

**Supplies**
- Dropped by: Wreckage, defeated enemies
- Used for: Ship repairs, shrine offerings, trading

**Cannonballs**
- Dropped by: Wreckage, Merchant Ships
- Used for: Combat damage boost (passive buff while held)

**Rum**
- Dropped by: Wreckage
- Used for: Shrine offerings, crew morale (healing)

**Ship Parts**
- Dropped by: Rare Wreckage drops, defeating bosses
- Used for: Permanent ship upgrades

### Secondary Resources

**Storm Bottles** (rare drop from Storm enemies)
- Used to: Craft wind-generating items, create Calm Waters tiles

**Kraken Teeth** (rare drop from deep-sea enemies)
- Used to: Unlock powerful ship abilities

**Sea Charts** (found in Islands)
- Used to: Reveal tile synergies, unlock new tile types

---

## Progression Systems

### Meta-Progression (Between Runs)

**Ship Upgrades**
- **Hull Reinforcement**: Start with +20 max HP
- **Faster Sails**: Complete loops 10% faster
- **Storm Weathering**: Reduce wave damage by 25%
- **Efficient Rigging**: Reduce Hold gain by 1 per loop

**Unlockable Tiles**
- Start with basic 5 tiles, unlock advanced tiles through achievements
- Example: "Defeat 50 Storm Elementals" → Unlocks Whirlpool Shrine

**Captain Abilities**
- Passive abilities that provide bonuses
- **Sea Dog**: +10% loot from Wreckage
- **Storm Chaser**: Storms give +2 bonus Wind
- **Veteran Sailor**: Waves have 20% less impact

**Ship Classes** (Different starting configurations)
- **Merchant Vessel**: Starts with 2 Merchant Ships placed, -10% Hold gain
- **Warship**: Stronger combat, +20% damage to enemies
- **Schooner**: +5 starting Wind, faster loop time

### In-Run Progression

**Ship HP & Combat Stats**
- Upgraded through found items and Island purchases
- Direct combat with enemies as you pass Reef/Storm tiles
- Death = lose all current Wind but Hold continues climbing (harsh penalty)

**Tile Synergies**
- Discover powerful combinations through experimentation
- Example: Trade Wind + Trade Wind + Trade Wind = "Trade Route" bonus (+5 extra Wind)
- Example: Reef + Wreckage = "Shipwreck" (better loot, tougher enemies)

---

## Core Game Loop

### Single Run Structure

1. **Loop Start** (Hold: 0, Wind: 0)
   - Ship begins sailing the circular route
   - You have a hand of random tiles to place

2. **Early Loops (Hold: 0-30)**
   - Place foundational tiles (Trade Winds, light Wreckage)
   - Establish basic resource generation
   - Few wave threats
   - Focus: Build economy safely

3. **Mid Loops (Hold: 30-60)**
   - Wave frequency increases
   - Must decide: aggressive (Storms) or defensive (Calm Waters)
   - Balance Wind generation with Hold management
   - Focus: Maximize Wind while managing risk

4. **Late Loops (Hold: 60-85)**
   - High tension - Hold climbing fast
   - Frequent waves, dangerous enemies
   - Critical decisions every loop
   - Focus: Sprint to 100 Wind before Hold catches up

5. **Endgame (Hold: 85-95)**
   - "Do or die" - must reach 100 Wind immediately
   - May need to use emergency tiles (Ancient Anchor)
   - All-in strategies (place multiple Storms for massive Wind rush)
   - Focus: Survive just long enough to escape

### Turn Structure (Per Loop)

**Phase 1: Sailing** (Auto)
- Ship moves around loop
- Passes tiles and triggers effects
- Combat with spawned enemies

**Phase 2: Loot & Events**
- Collect drops from defeated enemies
- Trigger tile effects (Shrines, Merchants)
- Random events can occur

**Phase 3: Planning**
- Hold and Wind meters update
- Draw new tiles from deck (if available)
- Wave warning appears if applicable

**Phase 4: Placement**
- Place 0-2 tiles on the route (limited by tile hand)
- Consider wave defense positioning
- Plan for upcoming synergies

**Phase 5: Loop Completion**
- Hold increases by base amount + tile penalties
- Check for wave trigger
- Check win/loss conditions

---

## UI/UX Design

### HUD Elements

**Primary Meters** (Top Center)
- Hold Meter: Red bar, 0-100, shows "death spiral" progress
- Wind Meter: Blue/white bar, 0-100, shows "escape" progress

**Ship Status** (Bottom Left)
- HP bar
- Current speed indicator
- Active buffs/debuffs

**Tile Hand** (Bottom Center)
- Show 3-5 tiles currently available to place
- Hover to see tile details and Hold/Wind effects

**Resources** (Top Right)
- Supplies, Cannonballs, Rum counts
- Rare items (Storm Bottles, Kraken Teeth)

**Wave Warning** (Top Center Flash)
- "WAVE INCOMING!" appears when wave will trigger next loop
- Shows predicted wave strength

### Visual Feedback

**Loop Path**
- Glows brighter as Hold increases (approaching danger)
- Darkens/tightens visually to show whirlpool pull
- Tiles on path have distinct, readable icons

**Ship Animation**
- Tilts inward toward center as Hold increases
- Sails fill as Wind increases
- Visible damage (cracks, torn sails) when HP is low

**Wave Events**
- Dramatic animation: huge wave crashes across path
- Visual destruction of tiles
- Screen shake and audio sting

---

## Difficulty Scaling

### Easy Mode
- Hold increases by +5 per loop (instead of +10)
- Waves less frequent (10% base instead of 15%)
- More forgiving wave damage (-10 Hold instead of -25)

### Normal Mode
- Balanced as described in core mechanics

### Hard Mode
- Hold increases by +15 per loop
- Waves more frequent (25% base chance)
- Fewer tiles in starting hand
- Less loot from Wreckage

### Endless Mode
- Victory condition removed (Wind meter capped at 100)
- Hold cap removed (can go above 100)
- Goal: Survive as many loops as possible
- Each loop gets progressively harder
- Leaderboard for highest loop count

---

## Audio Design

### Music
- **Early Loops**: Calm, eerie sea shanty
- **Mid Loops**: Tempo increases, drums added
- **Late Loops**: Intense orchestral, urgent strings
- **Wave Events**: Music cuts out, replaced by howling wind and crashing waves
- **Victory**: Triumphant swell as ship breaks free
- **Defeat**: Music fades into haunting depths sound

### SFX
- Tile placement: Satisfying "thunk" on water
- Enemy combat: Cannon fire, sword clashes, monster roars
- Wind generation: Whooshing wind, sail flutter
- Hold increase: Ominous low rumble
- Wave crash: Massive water impact

---

## Art Direction

### Visual Style
- **2D top-down perspective** (like Loop Hero)
- **Pixel art or hand-drawn style** (stylized, not realistic)
- **Color palette**: Deep blues, foamy whites, weathered browns, ominous blacks
- **Atmosphere**: Dark, stormy, desperate but with moments of beauty (sunbeams through clouds, bioluminescent creatures)

### Key Visual Elements
- Whirlpool center: Glowing, swirling abyss
- Ship: Detailed, shows progression and damage
- Tiles: Distinct silhouettes, readable at a glance
- Waves: Dramatic, almost "character-like" in their presence

---

## Development Roadmap

### Phase 1: Prototype (1 day)
- Basic loop with ship auto-sailing
- Core 5 tiles functional
- Hold and Wind meters working
- Simple combat system
- Wave events basic implementation

### Phase 2: Core Content (1 day)
- All core + advanced tiles implemented
- Meta-progression system
- Ship classes and captain abilities
- Full audio implementation
- UI/UX polish

### Phase 3: Polish & Balance (2 days)
- Extensive playtesting
- Balance tweaking (Hold rates, Wind gains, wave frequency)
- Tutorial and onboarding
- Achievements system
- Bug fixing

---

## Success Metrics

## Risks & Mitigation

### Risk: Too Similar to Loop Hero
**Mitigation**: Heavy emphasis on unique Hold/Wind mechanic and wave events. Nautical theme differentiates atmosphere.

### Risk: Difficulty Balance
**Mitigation**: Extensive playtesting with multiple difficulty modes. Tutorial teaches both defensive and aggressive strategies.

### Risk: Repetitive Gameplay
**Mitigation**: Deep meta-progression, multiple ship classes, tile variety, and synergy discovery keeps runs fresh.

### Risk: Technical Complexity (Wave Calculations)
**Mitigation**: Prototype wave system early. Keep calculations simple and deterministic.

---

## Conclusion

**Maelstrom's End** takes the proven Loop Hero formula and adds meaningful innovation through its dual-meter tension system and wave disruption mechanics. The nautical theme provides strong atmospheric cohesion, while the "escape the whirlpool" concept creates natural narrative stakes. The game respects the player's time with clear win/loss conditions while providing deep strategic decisions through tile placement and resource management.

The core loop is immediately understandable but offers mastery through tile synergies and risk management. With proper balancing and polish, Maelstrom's End has the potential to carve its own identity in the auto-battler roguelike space.

---

**Document Version**: 1.0  
**Last Updated**: November 2025  
**Status**: Prototype
