# Edge System - Renders tile slots along graph edges
#
# Core Concepts:
# - Renders the squares/tiles that appear along edges where the player moves
# - Each edge has multiple slots that can contain tiles
# - Slots are positioned along the pathfound route or linearly interpolated
# - Empty slots show as subtle markers, filled slots show tile icons
#
# Integration:
# - Called from renderer.rb during graph edge rendering
# - Uses tile_system.rb for slot positioning and tile constants
# - Uses ZIndex from renderer.rb for proper layering

# Require tile system for slot positioning and tile constants
require 'app/tile_system.rb'

# Tile slot size - larger for better visibility
TILE_SLOT_SIZE = 40  # Larger slots for readability

# Slot styling colors - simple and readable
SLOT_EMPTY_BG = { r: 50, g: 50, b: 50, a: 200 }       # Dark gray, visible
SLOT_EMPTY_BORDER = { r: 200, g: 200, b: 200, a: 200 } # Light gray border
SLOT_FILLED_BG = { r: 40, g: 40, b: 60, a: 220 }      # Slightly blue tint
SLOT_FILLED_BORDER = { r: 255, g: 220, b: 100, a: 255 } # Bright gold

# Renders tile slots along graph edges
# These are the squares the player moves through during gameplay
# Rendered dynamically each frame as tiles can be placed/removed
# ONLY renders slots on the current journey edge - not all possible edges
# Args:
#   args - DragonRuby args object containing state and outputs
#   z_index - Z-index value for rendering layer (from ZIndex::TILE_SLOTS)
def render_edge_tile_slots(args, z_index)
  half_size = TILE_SLOT_SIZE / 2
  icon_size = 32  # Icon size within slot

  # Only render slots on the current edge the ship is traveling on
  current_edge = get_current_edge(args.state)
  return unless current_edge

  # Also get the reverse edge (for return journey) to show its slots too
  edges_to_render = [current_edge]

  edges_to_render.each do |edge|
    edge[:slots].times do |i|
      tile = edge[:tiles][i]
      pos = edge_slot_position(args.state, edge[:id], i)

      if tile
        # === FILLED SLOT ===
        # Background
        args.outputs.primitives << {
          x: pos[:x] - half_size, y: pos[:y] - half_size,
          w: TILE_SLOT_SIZE, h: TILE_SLOT_SIZE,
          path: :solid,
          z: z_index
        }.merge(SLOT_FILLED_BG)

        # Tile icon
        icon_path = TILE_ICON_SPRITES[tile[:type]]
        if icon_path
          args.outputs.primitives << {
            x: pos[:x] - icon_size / 2, y: pos[:y] - icon_size / 2,
            w: icon_size, h: icon_size,
            path: icon_path,
            z: z_index + 1
          }
        else
          # Fallback to colored square
          color = TILE_COLORS[tile[:type]]
          args.outputs.primitives << {
            x: pos[:x] - icon_size / 2, y: pos[:y] - icon_size / 2,
            w: icon_size, h: icon_size,
            path: :solid,
            z: z_index + 1
          }.merge(color)
        end

        # Bright gold border for filled slots
        args.outputs.primitives << {
          x: pos[:x] - half_size, y: pos[:y] - half_size,
          w: TILE_SLOT_SIZE, h: TILE_SLOT_SIZE,
          z: z_index + 2,
          primitive_marker: :border
        }.merge(SLOT_FILLED_BORDER)
      else
        # === EMPTY SLOT ===
        # Background
        args.outputs.primitives << {
          x: pos[:x] - half_size, y: pos[:y] - half_size,
          w: TILE_SLOT_SIZE, h: TILE_SLOT_SIZE,
          path: :solid,
          z: z_index
        }.merge(SLOT_EMPTY_BG)

        # Muted gold border for empty slots
        args.outputs.primitives << {
          x: pos[:x] - half_size, y: pos[:y] - half_size,
          w: TILE_SLOT_SIZE, h: TILE_SLOT_SIZE,
          z: z_index + 2,
          primitive_marker: :border
        }.merge(SLOT_EMPTY_BORDER)
      end
    end
  end
end

