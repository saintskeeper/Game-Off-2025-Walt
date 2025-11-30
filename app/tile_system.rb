# Tile System - Handles tile data, placement, and slot positioning
#
# Core Concepts:
# - Hand holds 3 tiles the player can place
# - Tiles are hashes with :type key
# - Placement: click tile in hand, then click empty slot
# - Slots are positioned along graph edges
#
# Integration:
# - Called by game_state.rb for initial hand generation
# - Called by meter_system.rb to refill hand after loop completion
# - Called by input_handler.rb for tile placement
# - Used by renderer.rb for slot positioning

# Require graph_system for PATH_NODES and PATH_EDGES
require 'app/graph_system.rb'

# Tile types available in the game
# Each tile type has effects defined in meter_system.rb (TILE_EFFECTS)
TILE_TYPES = [:trade_wind, :storm, :calm_water, :wreckage]

# Color definitions for each tile type
# Used when rendering tiles in slots and hand
# RGB values (0-255) for visual distinction between tile types
# Note: Colors are kept for backwards compatibility, but icons are now preferred
TILE_COLORS = {
  trade_wind: { r: 100, g: 200, b: 255 },  # light blue
  storm:      { r: 100, g: 100, b: 150 },  # purple-gray
  calm_water: { r: 150, g: 220, b: 180 },  # soft green
  wreckage:   { r: 139, g: 90,  b: 43  }   # brown
}

# Mapping of tile types to their icon sprite paths
# Each tile type has a corresponding icon sprite used for rendering
# Used in both hand rendering (hud_system.rb) and slot rendering (renderer.rb)
TILE_ICON_SPRITES = {
  trade_wind: 'sprites/hud/hand-icons/trade_wind.png',
  storm:      'sprites/hud/hand-icons/storm.png',
  calm_water: 'sprites/hud/hand-icons/calm_waters.png',  # Note: file is calm_waters.png
  wreckage:   'sprites/hud/hand-icons/wreckage.png'
}

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

# Places a selected tile from hand into a slot on an edge
# Validates that slot is empty and tile is selected before placing
# Removes tile from hand after successful placement
# Args:
#   args - DragonRuby args object containing state
#   edge_id - Symbol identifying the edge
#   local_slot_index - Index within the edge's tile array
def place_tile_on_edge(args, edge_id, local_slot_index)
  state = args.state
  return unless state.selected_tile  # No tile selected, can't place

  edge = get_edge(state, edge_id)
  return unless edge  # Invalid edge

  # Verify slot is empty (nil = empty slot)
  return if edge[:tiles][local_slot_index]  # Slot already occupied

  # Verify selected_tile index is valid
  return unless state.selected_tile >= 0 && state.selected_tile < state.hand.length

  # Place the tile in the slot
  edge[:tiles][local_slot_index] = state.hand[state.selected_tile]

  # Remove tile from hand
  state.hand.delete_at(state.selected_tile)

  # Clear selection after placement
  state.selected_tile = nil

  # Invalidate map render target to force rebuild with new tile
  args.state.map_render_target_built = false
end

# Calculates the screen position (x, y) of a slot along an edge
# Interpolates between the edge's from_node and to_node positions
# Args:
#   state - Game state object containing graph data
#   edge_id - Symbol identifying the edge
#   local_slot_index - Index within the edge (0 to edge.slots-1)
# Returns:
#   Hash with :x and :y keys for the slot's center position
def edge_slot_position(state, edge_id, local_slot_index)
  edge = get_edge(state, edge_id)
  return { x: 0, y: 0 } unless edge

  # If edge has a pathfound route, use it
  if edge[:path] && edge[:path].length > 1
    require 'app/graph_system_dynamic.rb'
    return get_edge_path_position(edge, local_slot_index)
  end

  # Fallback to linear interpolation
  from_node = state.path_nodes[edge[:from]]
  to_node = state.path_nodes[edge[:to]]

  # Calculate interpolation factor (0.0 to 1.0)
  progress = local_slot_index.to_f / edge[:slots]

  # Linear interpolation between from and to node positions
  {
    x: from_node[:position][:x] + ((to_node[:position][:x] - from_node[:position][:x]) * progress),
    y: from_node[:position][:y] + ((to_node[:position][:y] - from_node[:position][:y]) * progress)
  }
end

# Calculates the collision rectangle for a slot (used for click detection)
# Returns a rect hash suitable for args.geometry.inside_rect? checks
# Args:
#   state - Game state object containing graph data
#   edge_id - Symbol identifying the edge
#   local_slot_index - Index within the edge
# Returns:
#   Hash with :x, :y, :w, :h keys for collision detection
def edge_slot_rect(state, edge_id, local_slot_index)
  pos = edge_slot_position(state, edge_id, local_slot_index)
  # 40x40 pixel rectangle centered on slot position
  { x: pos[:x] - 20, y: pos[:y] - 20, w: 40, h: 40 }
end

