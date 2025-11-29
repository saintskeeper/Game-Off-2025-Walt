# Input Handler - Handles mouse click interactions
#
# Core Concepts:
# - DragonRuby: args.inputs.mouse.click is truthy on click frame
# - args.inputs.mouse.point gives {x, y} of cursor
# - Collision: args.geometry.inside_rect?(point, rect)
# - Two-phase click: select from hand, then place on slot
#
# Integration:
# - Called from main.rb before update_ship each tick
# - Uses tile_system.rb for place_tile and slot_rect functions
# - Uses loop_system.rb for SLOT_COUNT constant

# Require tile_system for place_tile and slot_rect functions
require 'app/tile_system.rb'

# Require loop_system for SLOT_COUNT constant
require 'app/loop_system.rb'

# Constants for hand tile positioning on screen
# Hand tiles are displayed at the bottom of the screen
HAND_START_X = 440  # Starting X position of first tile
HAND_Y = 50         # Y position (bottom of screen)
HAND_TILE_SIZE = 80  # Size of each tile in hand (width and height)
HAND_SPACING = 100   # Spacing between tiles in hand

# Main input handling function - processes mouse clicks each tick
# Handles two-phase interaction: select tile from hand, then place on slot
# Algorithm:
#   1. Check if clicked on hand tile -> select it
#   2. Check if clicked on empty slot (with tile selected) -> place tile
#   3. Clicked elsewhere -> deselect tile
# Args:
#   args - DragonRuby args object containing inputs and state
def handle_input(args)
  # Only process input on frames where mouse was clicked
  return unless args.inputs.mouse.click

  # Get mouse position for collision detection
  mouse = args.inputs.mouse.point

  # Phase 1: Check if clicked on a tile in hand
  # If clicked on hand tile, select it and return (don't check slots)
  args.state.hand.each_with_index do |tile, i|
    rect = hand_tile_rect(i)
    if args.geometry.inside_rect?(mouse, rect)
      args.state.selected_tile = i
      return  # Exit early - tile selected, don't check slots
    end
  end

  # Phase 2: Check if clicked on a loop slot (only if tile is selected)
  # If clicked on empty slot with tile selected, place the tile
  if args.state.selected_tile
    SLOT_COUNT.times do |i|
      rect = slot_rect(i)
      if args.geometry.inside_rect?(mouse, rect)
        place_tile(args, i)
        return  # Exit early - tile placed
      end
    end
  end

  # Phase 3: Clicked elsewhere (not on hand, not on slot)
  # Deselect any selected tile
  args.state.selected_tile = nil
end

# Calculates the collision rectangle for a tile in the player's hand
# Used for click detection to determine which hand tile was clicked
# Args:
#   index - Index (0-2) of the tile in the hand array
# Returns:
#   Hash with :x, :y, :w, :h keys for collision detection
def hand_tile_rect(index)
  {
    x: HAND_START_X + (index * HAND_SPACING),
    y: HAND_Y,
    w: HAND_TILE_SIZE,
    h: HAND_TILE_SIZE
  }
end

