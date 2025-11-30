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
# NOTE: This is called from navigation_system when ship moves, but encounters
# should be handled separately by the encounter system, not here
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

  # Don't check victory here - victory is only triggered by reaching the end node
  # Wind meter is for gameplay effects, not victory condition
  # check_victory(args)  # Removed - causes instant victory on tile encounter
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
# Automatically starts return journey back to Caribbean port
# Args:
#   args - DragonRuby args object containing state
def on_journey_complete(args)
  state = args.state

  # Increment journey count to track how many times we've completed the route
  state.journey_count ||= 0
  state.journey_count += 1

  # We're at the European port, so find the return edge back to Mid-Atlantic
  # The graph now has return paths: European Port -> Mid-Atlantic -> Caribbean Port
  end_node_id = state.end_node || :european_port

  # Find the first edge from the European port (return journey)
  return_edge = state.path_edges.find { |e| e[:from] == end_node_id }

  if return_edge
    # Start return journey from European port
    state.ship[:current_edge] = return_edge[:id]
    state.ship[:edge_progress] = 0
    state.ship[:journey_phase] = :return  # Mark as return journey
    state.ship[:path_history] << end_node_id unless state.ship[:path_history].include?(end_node_id)

    # Check if we entered a slot with a tile at the start
    tile = return_edge[:tiles][0]
    on_enter_slot(args, tile) if tile

    puts "[JOURNEY] Completed journey #{state.journey_count}, starting return to Caribbean"
  else
    # Fallback: if no return path exists, reset to Caribbean port
    start_node_id = state.start_node || :caribbean_port
    first_edge = state.path_edges.find { |e| e[:from] == start_node_id }

    if first_edge
      state.ship[:current_edge] = first_edge[:id]
      state.ship[:edge_progress] = 0
      state.ship[:journey_phase] = :outbound
      state.ship[:path_history] = [start_node_id]
      puts "[JOURNEY] No return path found, resetting to Caribbean port"
    else
      puts "WARNING: Could not find return edge from European port or reset edge from Caribbean port"
    end
  end

  # Note: We don't set victory to true here - the game continues
  # This allows players to make multiple journeys back and forth
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

