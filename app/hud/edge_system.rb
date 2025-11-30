# Edge System - Renders tile slots along graph edges
#
# Core Concepts:
# - Renders the squares/tiles that appear along edges where the player moves
# - Each edge has multiple slots that can contain tiles
# - Slots are positioned along the pathfound route or linearly interpolated
# - Empty slots show as gray borders, filled slots show tile icons or colors
#
# Integration:
# - Called from renderer.rb during graph edge rendering
# - Uses tile_system.rb for slot positioning and tile constants
# - Uses ZIndex from renderer.rb for proper layering

# Require tile system for slot positioning and tile constants
require 'app/tile_system.rb'

# Renders tile slots along graph edges
# These are the squares the player moves through during gameplay
# Rendered dynamically each frame as tiles can be placed/removed
# Skips every even-indexed square, but always renders first and last squares
# Args:
#   args - DragonRuby args object containing state and outputs
#   z_index - Z-index value for rendering layer (from ZIndex::TILE_SLOTS)
def render_edge_tile_slots(args, z_index)
  # Draw tile slots along edge (rendered dynamically each frame)
  args.state.path_edges.each do |edge|
    last_index = edge[:slots] - 1

    edge[:slots].times do |i|
      # Skip even-indexed squares, but always render first (0) and last
      # This means: render 0, skip 2/4/6..., render 1/3/5..., always render last
      is_first = i == 0
      is_last = i == last_index
      is_even = i.even?

      # Skip if even-indexed, unless it's the first or last square
      next if is_even && !is_first && !is_last

      pos = edge_slot_position(args.state, edge[:id], i)
      tile = edge[:tiles][i]

      if tile
        icon_path = TILE_ICON_SPRITES[tile[:type]]
        if icon_path
          args.outputs.primitives << {
            x: pos[:x] - 20, y: pos[:y] - 20,
            w: 40, h: 40,
            path: icon_path,
            z: z_index
          }
        else
          color = TILE_COLORS[tile[:type]]
          args.outputs.primitives << {
            x: pos[:x] - 20, y: pos[:y] - 20,
            w: 40, h: 40,
            path: :solid,
            z: z_index
          }.merge(color)
        end
      else
        args.outputs.primitives << {
          x: pos[:x] - 20, y: pos[:y] - 20,
          w: 40, h: 40,
          r: 80, g: 80, b: 80,
          z: z_index,
          primitive_marker: :border
        }
      end
    end
  end
end

