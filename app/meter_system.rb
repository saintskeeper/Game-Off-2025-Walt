# Meter System - Handles Hold/Wind meters and win/loss conditions
#
# Core Concepts:
# - Two competing meters racing to 100
# - Hold increases automatically each loop (+10 base)
# - Wind increases from tile effects when ship passes
# - Meters are clamped to 0-100 range
#
# Integration:
# - Called by loop_system.rb when ship enters slots or completes loops
# - Calls check_victory() and check_game_over() when thresholds reached

# Tile effect definitions mapping each tile type to its gameplay impact
# wind_on_pass: Wind gained when ship passes over this tile
# hold_per_loop: Hold gained/lost per loop completion when this tile is present
TILE_EFFECTS = {
  trade_wind: { wind_on_pass: 5,  hold_per_loop: 0 },
  storm:      { wind_on_pass: 15, hold_per_loop: 5 },
  calm_water: { wind_on_pass: 0,  hold_per_loop: -3 },
  wreckage:   { wind_on_pass: 3,  hold_per_loop: 2 }
}

# Called when ship enters a slot with a tile
# Triggers wind gain based on tile type
# Args:
#   args - DragonRuby args object containing state
#   tile - Tile hash (or nil if empty slot)
def on_enter_slot(args, tile)
  return unless tile  # Slot is empty, no effect

  # Look up the effect for this tile type
  effect = TILE_EFFECTS[tile[:type]]
  return unless effect  # Unknown tile type, skip

  # Add wind gain from passing over this tile
  args.state.wind = (args.state.wind + effect[:wind_on_pass]).clamp(0, 100)

  # Check if victory condition met (wind reached 100)
  check_victory(args)
end

# Called when ship completes a full loop (returns to start)
# NOTE: This is kept for backwards compatibility but not used in linear journey mode
# Calculates hold gain based on base value + tile modifiers
# Also triggers wave system and hand refill
# Args:
#   args - DragonRuby args object containing state
def on_loop_complete(args)
  state = args.state
  state.loop_count += 1

  # Collect all tiles from all edges
  all_tiles = []
  state.path_edges.each do |edge|
    all_tiles.concat(edge[:tiles].compact)
  end

  # Calculate hold gain: base 10 + modifiers from each tile
  hold_gain = 10  # Base hold gain per loop
  all_tiles.each do |tile|
    effect = TILE_EFFECTS[tile[:type]]
    next unless effect  # Skip unknown tile types
    hold_gain += effect[:hold_per_loop]
  end

  # Ensure minimum gain of 0 (no negative hold gains)
  hold_gain = [hold_gain, 0].max

  # Add hold gain and clamp to 0-100 range
  state.hold = (state.hold + hold_gain).clamp(0, 100)

  # Check if game over condition met (hold reached 100)
  check_game_over(args)

  # Trigger wave system (15% chance to destroy random tile)
  # Implemented in wave_system.rb
  maybe_trigger_wave(args)

  # Refill player hand with new tiles
  refill_hand(args)
end

# Called when ship reaches the European port (end of journey)
# This triggers victory condition - player successfully delivered rum to Europe
# Args:
#   args - DragonRuby args object containing state
def on_journey_complete(args)
  # Victory condition: reached the European port
  # Wind and hold mechanics still work during journey, but victory is reaching destination
  check_victory(args)
end

# Checks if victory condition is met
# In linear journey mode: victory is reaching the European port (set by on_journey_complete)
# Wind meter can still be used for gameplay but doesn't trigger victory
# Args:
#   args - DragonRuby args object containing state
def check_victory(args)
  # Victory is triggered by reaching the end node (European port)
  # This is set by on_journey_complete() in navigation_system.rb
  # We just need to ensure the flag is set
  args.state.victory = true
end

# Checks if game over condition is met (hold meter reached 100)
# Sets game_over flag to true if condition is satisfied
# Args:
#   args - DragonRuby args object containing state
def check_game_over(args)
  args.state.game_over = true if args.state.hold >= 100
end

