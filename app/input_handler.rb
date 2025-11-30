# Input Handler - Handles mouse click interactions
#
# Core Concepts:
# - DragonRuby: args.inputs.mouse.click is truthy on click frame
# - args.inputs.mouse.point gives {x, y} of cursor
# - Collision: args.geometry.inside_rect?(point, rect)
# - Three-phase click: select from hand, choose path at branch, or place/move on slot
#
# Integration:
# - Called from main.rb each tick
# - Uses graph_system.rb for node/edge queries
# - Uses navigation_system.rb for ship movement
# - Uses tile_system.rb for tile placement

# Require systems for navigation and tile placement
require 'app/graph_system.rb'
require 'app/navigation_system.rb'
require 'app/tile_system.rb'

# Constants for hand tile positioning on screen
# Hand tiles are displayed at the bottom of the screen
HAND_START_X = 440  # Starting X position of first tile
HAND_Y = 50         # Y position (bottom of screen)
HAND_TILE_SIZE = 80  # Size of each tile in hand (width and height)
HAND_SPACING = 100   # Spacing between tiles in hand

# Main input handling function - processes mouse clicks each tick
# Handles multi-phase interaction:
#   1. Select tile from hand
#   2. Choose path at branch points
#   3. Place tile on slot or advance ship
# Args:
#   args - DragonRuby args object containing inputs and state
def handle_input(args)
  # Only process input on frames where mouse was clicked
  return unless args.inputs.mouse.click

  # Get mouse position for collision detection
  mouse = args.inputs.mouse.point

  # Phase 1: Check if clicked on a tile in hand
  args.state.hand.each_with_index do |tile, i|
    rect = hand_tile_rect(i)
    if args.geometry.inside_rect?(mouse, rect)
      args.state.selected_tile = i
      return  # Exit early - tile selected
    end
  end

  # Phase 2: Check for branch point node clicks (path selection)
  # If ship is at a branch point, allow clicking destination nodes
  next_edges = get_next_edge_choices(args.state)
  unless next_edges.empty?
    next_edges.each do |edge|
      to_node = args.state.path_nodes[edge[:to]]
      node_rect = {
        x: to_node[:position][:x] - 20,
        y: to_node[:position][:y] - 20,
        w: 40,
        h: 40
      }

      if args.geometry.inside_rect?(mouse, node_rect)
        advance_ship(args, edge[:id])
        return  # Exit early - path chosen
      end
    end
  end

  # Phase 3: Check if clicked on a slot on current edge
  # Either place tile (if selected) or advance ship (if next slot)
  current_edge = get_current_edge(args.state)
  current_edge[:slots].times do |i|
    rect = edge_slot_rect(args.state, current_edge[:id], i)

    next unless args.geometry.inside_rect?(mouse, rect)

    if args.state.selected_tile
      # Placing a tile
      place_tile_on_edge(args, current_edge[:id], i)
      return  # Exit early - tile placed
    elsif i == args.state.ship[:edge_progress] + 1
      # Moving ship forward one slot
      advance_ship(args)
      return  # Exit early - ship advanced
    end
  end

  # Phase 4: Clicked elsewhere - deselect
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

