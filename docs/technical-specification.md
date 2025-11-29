# MAELSTROM'S END - Technical Specification
## DragonRuby Implementation Document

---

## 1. Technical Architecture Overview

### Core Engine Requirements
- **DragonRuby GTK** (latest stable version)
- **Target FPS**: 60fps constant
- **Resolution**: 1280x720 (16:9) with scaling support
- **Platform**: Cross-platform (Windows, macOS, Linux)

### Project Structure
```
mygame/
├── app/
│   ├── main.rb              # Entry point & game loop
│   ├── game_state.rb        # Core game state management
│   ├── systems/
│   │   ├── loop_system.rb   # Circular path & ship movement
│   │   ├── meter_system.rb  # Hold/Wind meter logic
│   │   ├── tile_system.rb   # Tile placement & effects
│   │   └── wave_system.rb   # Wave event handling
│   ├── entities/
│   │   ├── ship.rb          # Ship entity
│   │   ├── tile.rb          # Tile base class
│   │   └── tiles/          # Specific tile implementations
│   ├── ui/
│   │   ├── meters_ui.rb    # Hold/Wind meter display
│   │   ├── hand_ui.rb      # Tile hand interface
│   │   └── loop_ui.rb      # Circular path rendering
│   └── utils/
│       ├── constants.rb    # Game constants
│       └── math_helpers.rb # Circle math utilities
├── sprites/                # Image assets
├── sounds/                 # Audio assets
└── data/                   # Configuration files
```

---

## 2. Core Systems Technical Design

### 2.1 Loop System
**Purpose**: Manage circular path navigation and ship movement

#### Data Structures
```ruby
class LoopSystem
  attr_accessor :ship_position      # Float: 0.0 to 1.0 (percentage of loop)
  attr_accessor :ship_speed         # Float: loops per second
  attr_accessor :loop_radius        # Integer: pixels from center
  attr_accessor :tile_slots         # Array: 12-16 tile positions
  attr_accessor :loops_completed    # Integer: counter

  TILE_SLOT_COUNT = 16
  SECONDS_PER_LOOP = 8.0
  LOOP_CENTER_X = 640
  LOOP_CENTER_Y = 360
end
```

#### Key Methods
- `update(delta_time)` - Updates ship position
- `get_ship_coordinates()` - Converts position to x,y
- `get_tile_slot_coordinates(index)` - Returns x,y for tile slot
- `check_tile_trigger()` - Detects when ship passes tile
- `on_loop_complete()` - Triggers end-of-loop events

### 2.2 Meter System
**Purpose**: Track Hold/Wind meters and win/loss conditions

#### Data Structures
```ruby
class MeterSystem
  attr_accessor :hold_value        # Integer: 0-100
  attr_accessor :wind_value        # Integer: 0-100
  attr_accessor :hold_modifiers    # Array: per-loop modifiers
  attr_accessor :wind_accumulated  # Integer: wind gained this loop

  BASE_HOLD_INCREASE = 10
  MAX_METER_VALUE = 100
  MIN_METER_VALUE = 0
end
```

#### Key Methods
- `apply_loop_effects()` - Applies hold increase & modifiers
- `add_wind(amount)` - Accumulates wind
- `add_hold(amount)` - Increases hold
- `check_game_end()` - Returns :victory, :defeat, or :ongoing
- `reset_loop_modifiers()` - Clears temporary effects

### 2.3 Tile System
**Purpose**: Handle tile placement, storage, and effect triggers

#### Data Structures
```ruby
class TileSystem
  attr_accessor :placed_tiles      # Hash: {slot_index => Tile}
  attr_accessor :hand_tiles        # Array: 3 available tiles
  attr_accessor :tile_deck         # Array: available tile types

  HAND_SIZE = 3
  TILE_TYPES = [:trade_wind, :storm, :calm_water, :wreckage]
end

class Tile
  attr_accessor :type              # Symbol: tile type
  attr_accessor :slot_index        # Integer: position on loop
  attr_accessor :wind_value        # Integer: wind generated
  attr_accessor :hold_modifier     # Integer: hold per loop
  attr_accessor :durability        # Integer: uses remaining (future)
end
```

#### Tile Definitions
```ruby
TILE_DEFINITIONS = {
  trade_wind: {
    wind_value: 5,
    hold_modifier: 0,
    color: [100, 200, 255],  # Light blue
    icon: :wind_icon
  },
  storm: {
    wind_value: 15,
    hold_modifier: 5,
    color: [150, 150, 200],  # Gray-blue
    icon: :storm_icon
  },
  calm_water: {
    wind_value: 0,
    hold_modifier: -3,
    color: [100, 255, 200],  # Teal
    icon: :calm_icon
  },
  wreckage: {
    wind_value: 3,
    hold_modifier: 2,
    color: [200, 150, 100],  # Brown
    icon: :wreck_icon
  }
}
```

#### Key Methods
- `place_tile(tile_type, slot_index)` - Places tile on loop
- `remove_tile(slot_index)` - Removes tile from slot
- `trigger_tile_effect(tile)` - Executes tile's effect
- `refresh_hand()` - Generates 3 new tiles
- `can_place_at?(slot_index)` - Validates placement

### 2.4 Wave System
**Purpose**: Random tile destruction events

#### Data Structures
```ruby
class WaveSystem
  attr_accessor :wave_chance       # Float: 0.0-1.0
  attr_accessor :wave_animation    # Hash: animation state

  DEFAULT_WAVE_CHANCE = 0.15
  ANIMATION_DURATION = 0.5  # seconds
end
```

#### Key Methods
- `check_wave_trigger()` - Random roll for wave
- `execute_wave()` - Destroys random tile
- `select_target_tile()` - Chooses tile to destroy
- `play_wave_animation()` - Visual feedback

---

## 3. Game State Management

### Core Game State
```ruby
class GameState
  attr_accessor :game_phase        # :menu, :playing, :victory, :defeat
  attr_accessor :loop_system
  attr_accessor :meter_system
  attr_accessor :tile_system
  attr_accessor :wave_system
  attr_accessor :input_state       # Mouse/touch tracking
  attr_accessor :animation_queue   # Active animations

  # Statistics
  attr_accessor :total_loops
  attr_accessor :tiles_placed
  attr_accessor :waves_survived
  attr_accessor :game_duration
end
```

### State Transitions
```
MENU → PLAYING → VICTORY/DEFEAT → MENU
         ↑              ↓
         └──── RESET ───┘
```

---

## 4. Input System

### Mouse/Touch Input
```ruby
class InputHandler
  # States
  IDLE = 0
  TILE_SELECTED = 1
  DRAGGING = 2

  attr_accessor :selected_tile_index  # Which hand tile selected
  attr_accessor :hover_slot           # Which loop slot hovering
  attr_accessor :drag_position        # Current drag x,y
end
```

### Input Processing Pipeline
1. **Mouse Down**: Check if over hand tile → Set selected
2. **Mouse Move**: Update hover slot, show placement preview
3. **Mouse Up**: If valid slot → Place tile, else cancel

---

## 5. Rendering Pipeline

### Layer Order (Back to Front)
1. **Background** (static)
2. **Whirlpool effect** (animated)
3. **Loop path** (static circle)
4. **Placed tiles** (on loop)
5. **Ship** (animated position)
6. **UI elements** (meters, hand)
7. **Effects** (particles, waves)
8. **Debug info** (if enabled)

### Render Methods
```ruby
def render(args)
  render_background(args)
  render_loop_path(args)
  render_placed_tiles(args)
  render_ship(args)
  render_meters(args)
  render_tile_hand(args)
  render_active_effects(args)
  render_debug(args) if $debug_mode
end
```

---

## 6. Animation System

### Animation Types
```ruby
ANIMATIONS = {
  ship_movement: {
    type: :continuous,
    interpolation: :linear
  },
  tile_placement: {
    type: :one_shot,
    duration: 0.3,
    interpolation: :ease_out
  },
  wave_destroy: {
    type: :one_shot,
    duration: 0.5,
    interpolation: :ease_in
  },
  meter_change: {
    type: :one_shot,
    duration: 0.2,
    interpolation: :linear
  }
}
```

---

## 7. Performance Optimization

### DragonRuby-Specific Optimizations
1. **Static Sprites**: Pre-render loop and UI elements
2. **Sprite Batching**: Group similar renders
3. **Dirty Rectangle**: Only update changed regions
4. **Object Pooling**: Reuse tile and effect objects

### Performance Targets
- **Frame Time**: < 16ms (60fps)
- **Memory Usage**: < 100MB
- **Sprite Draw Calls**: < 100 per frame
- **Update Time**: < 5ms per frame

---

## 8. Data Flow Diagram

```
Game Loop (60fps)
    ↓
Input Processing
    ↓
System Updates (Sequential)
    ├── Loop System (ship movement)
    ├── Tile System (trigger checks)
    ├── Meter System (value updates)
    └── Wave System (event checks)
    ↓
Game State Validation
    ├── Win/Loss Check
    └── Animation Updates
    ↓
Render Pipeline
    ↓
Frame Output
```

---

## 9. Mathematical Functions

### Critical Calculations
```ruby
# Convert loop position to screen coordinates
def position_to_coords(position, radius)
  angle = position * Math::PI * 2
  x = Math.cos(angle) * radius + CENTER_X
  y = Math.sin(angle) * radius + CENTER_Y
  return [x, y]
end

# Calculate distance along loop
def loop_distance(pos1, pos2)
  diff = (pos2 - pos1).abs
  return [diff, 1.0 - diff].min
end

# Check if ship overlaps tile slot
def ship_at_slot?(ship_pos, slot_index, threshold = 0.0625)
  slot_pos = slot_index.to_f / TILE_SLOT_COUNT
  return loop_distance(ship_pos, slot_pos) < threshold
end
```

---

## 10. Debug Features

### Development Tools
```ruby
DEBUG_FEATURES = {
  show_fps: true,
  show_meters_numeric: true,
  show_loop_positions: true,
  instant_win: 'W key',
  instant_lose: 'L key',
  force_wave: 'V key',
  reset_game: 'R key',
  speed_multiplier: '1-5 keys'
}
```

---

## 11. Implementation Timeline

### Phase 1: Core Loop (4 hours)
1. **Hour 1**: Project setup, basic rendering
2. **Hour 2**: Ship movement on circular path
3. **Hour 3**: Meter system implementation
4. **Hour 4**: Win/loss conditions

### Phase 2: Tile System (3 hours)
1. **Hour 5**: Tile placement mechanics
2. **Hour 6**: Tile effect triggers
3. **Hour 7**: Hand UI and refresh

### Phase 3: Polish (3 hours)
1. **Hour 8**: Wave events
2. **Hour 9**: Visual feedback & animations
3. **Hour 10**: Balance testing & tweaks

---

## 12. Testing Checklist

### Core Functionality
- [ ] Ship completes loops in 8 seconds
- [ ] Hold increases by 10 per loop
- [ ] All 4 tile types function correctly
- [ ] Tiles can be placed and removed
- [ ] Wave events trigger at 15% chance
- [ ] Win condition at Wind = 100
- [ ] Loss condition at Hold = 100

### Edge Cases
- [ ] Placing tile on occupied slot
- [ ] Wave hitting empty slot
- [ ] Multiple tiles triggering same frame
- [ ] Meter overflow/underflow
- [ ] Rapid clicking/placement

### Performance
- [ ] Maintains 60fps with all tiles placed
- [ ] No memory leaks over 10-minute session
- [ ] Smooth animations under load

---

## 13. Configuration Constants

```ruby
# Game Balance
GAME_CONSTANTS = {
  # Timing
  seconds_per_loop: 8.0,
  animation_speed: 1.0,

  # Meters
  max_meter_value: 100,
  base_hold_increase: 10,

  # Loop
  tile_slots: 16,
  loop_radius: 200,

  # Waves
  wave_chance: 0.15,
  tiles_destroyed_per_wave: 1,

  # UI
  meter_bar_width: 300,
  meter_bar_height: 30,
  hand_tile_size: 80,
  loop_tile_size: 60
}
```

---

## 14. Error Handling

### Critical Errors (Stop Game)
- Missing sprite assets
- Invalid game state
- Meter value corruption

### Recoverable Errors (Log & Continue)
- Animation glitches
- Sound playback failures
- Non-critical asset loading

---

## 15. Save State Structure (Post-MVP)

```ruby
SAVE_DATA = {
  version: "1.0",
  statistics: {
    games_played: 0,
    victories: 0,
    total_loops: 0,
    tiles_placed: 0
  },
  unlocks: [],
  settings: {
    sound_enabled: true,
    music_volume: 0.7,
    sfx_volume: 0.8
  }
}
```

---

**Document Version**: 1.0
**Last Updated**: Technical Specification for MVP
**Scope**: 2-day development sprint
**Target Platform**: DragonRuby GTK