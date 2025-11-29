# Tile System - Handles tile data, placement, and slot positioning
#
# Core Concepts:
# - Hand holds 3 tiles the player can place
# - Tiles are hashes with :type key
# - Placement: click tile in hand, then click empty slot
# - Slots are positioned around the loop circle
#
# Integration:
# - Called by game_state.rb for initial hand generation
# - Called by meter_system.rb to refill hand after loop completion
# - Called by input_handler.rb for tile placement
# - Used by renderer.rb for slot positioning

# Require loop_system for constants (LOOP_CENTER_X, LOOP_RADIUS, SLOT_COUNT, TWO_PI)
require 'app/loop_system.rb'

# Tile types available in the game
# Each tile type has effects defined in meter_system.rb (TILE_EFFECTS)
TILE_TYPES = [:trade_wind, :storm, :calm_water, :wreckage]

# Generates a hand of 3 random tiles for the player
# Returns an array of tile hashes, each with a :type key
# Used during initial state setup and after loop completion
def generate_hand
  3.times.map { { type: TILE_TYPES.sample } }
end

# Refills the player's hand with 3 new random tiles
# Also clears the selected_tile since hand changed
# Called from meter_system.rb when a loop completes
# Args:
#   args - DragonRuby args object containing state
def refill_hand(args)
  args.state.hand = generate_hand
  args.state.selected_tile = nil
end

# Places a selected tile from hand into a slot on the loop
# Validates that slot is empty and tile is selected before placing
# Removes tile from hand after successful placement
# Args:
#   args - DragonRuby args object containing state
#   slot_index - Index (0-11) of the slot to place tile in
def place_tile(args, slot_index)
  state = args.state
  return unless state.selected_tile  # No tile selected, can't place

  # Verify slot is empty (nil = empty slot)
  return if state.loop_slots[slot_index]  # Slot already occupied

  # Verify selected_tile index is valid
  return unless state.selected_tile >= 0 && state.selected_tile < state.hand.length

  # Place the tile in the slot
  state.loop_slots[slot_index] = state.hand[state.selected_tile]

  # Remove tile from hand (this shifts indices, but we're done with selected_tile)
  state.hand.delete_at(state.selected_tile)

  # Clear selection after placement
  state.selected_tile = nil
end

# Calculates the screen position (x, y) of a slot around the loop circle
# Uses polar to cartesian conversion with the same formula as ship positioning
# Args:
#   slot_index - Index (0-11) of the slot
# Returns:
#   Hash with :x and :y keys for the slot's center position
def slot_position(slot_index)
  # Calculate angle for this slot (12 slots evenly spaced around circle)
  angle = (slot_index.to_f / SLOT_COUNT) * TWO_PI

  # Convert polar coordinates to cartesian (same formula as ship_position)
  {
    x: LOOP_CENTER_X + LOOP_RADIUS * Math.cos(angle),
    y: LOOP_CENTER_Y + LOOP_RADIUS * Math.sin(angle)
  }
end

# Calculates the collision rectangle for a slot (used for click detection)
# Returns a rect hash suitable for args.geometry.inside_rect? checks
# Args:
#   slot_index - Index (0-11) of the slot
# Returns:
#   Hash with :x, :y, :w, :h keys for collision detection
def slot_rect(slot_index)
  pos = slot_position(slot_index)
  # 40x40 pixel rectangle centered on slot position
  { x: pos[:x] - 20, y: pos[:y] - 20, w: 40, h: 40 }
end

