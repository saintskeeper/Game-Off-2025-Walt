# HUD System - Handles rendering of Heads-Up Display elements
#
# Core Concepts:
# - Handles player hand rendering with sprites
# - Uses sprite backgrounds with tile type icons in center
# - Maintains visual feedback for selected tiles
#
# Integration:
# - Called from renderer.rb
# - Uses constants from input_handler.rb for positioning
# - Uses tile type mapping to sprite icons

# Require input_handler for hand positioning constants and functions
require 'app/input_handler.rb'
# Require tile_system for tile type constants and icon sprite mapping
require 'app/tile_system.rb'

# Path to the hand tile sprite background
# This sprite is used as the background for each tile in the player's hand
HAND_TILE_SPRITE = 'sprites/hud/thanksgiving-jam-2_export.png'
# Note: TILE_ICON_SPRITES is now defined in tile_system.rb for shared access

# Size of the tile icon that appears in the center of each tile sprite
# This provides visual indication of the tile type
ICON_SIZE = 40  # Size of the icon sprite in the center

# Renders the player's hand (3 tiles at bottom of screen)
# Uses sprite backgrounds with tile type icons in the center
# Highlights the selected tile with a yellow border
# Args:
#   args - DragonRuby args object containing state and outputs
def render_hand(args)
  args.state.hand.each_with_index do |tile, i|
    # Get collision rectangle for this hand tile (positioning from input_handler)
    rect = hand_tile_rect(i)

    # Draw sprite background for the tile
    # The sprite provides the visual frame/background for each hand tile
    # z: 200 ensures hand tiles render above map background and all game elements
    # Using high z value to ensure it appears above static_sprites background
    args.outputs.sprites << {
      x: rect[:x],
      y: rect[:y],
      w: rect[:w],
      h: rect[:h],
      path: HAND_TILE_SPRITE,
      z: 200
    }

    # Draw tile type icon in the center of the sprite
    # This provides visual indication of the tile type using the appropriate icon sprite
    # Get icon sprite path from TILE_ICON_SPRITES mapping
    icon_path = TILE_ICON_SPRITES[tile[:type]]
    if icon_path
      # Calculate center position for the icon
      center_x = rect[:x] + (rect[:w] / 2) - (ICON_SIZE / 2)
      center_y = rect[:y] + (rect[:h] / 2) - (ICON_SIZE / 2)

      # Draw the tile type icon sprite centered on the background sprite
      # This renders in the sprite layer, ensuring it appears above the background sprite
      # z: 201 ensures icon renders above the hand tile background (z: 200)
      args.outputs.sprites << {
        x: center_x,
        y: center_y,
        w: ICON_SIZE,
        h: ICON_SIZE,
        path: icon_path,
        z: 201
      }
    end

    # Highlight selected tile with yellow border (thicker, offset)
    # Visual feedback to show which tile is currently selected
    # z: 202 ensures selection border renders above hand tiles (z: 200) and icons (z: 201)
    if args.state.selected_tile == i
      args.outputs.borders << {
        x: rect[:x] - 2,
        y: rect[:y] - 2,
        w: rect[:w] + 4,
        h: rect[:h] + 4,
        r: 255,
        g: 255,
        b: 0,
        z: 202
      }
    end

    # Tile name label (below tile, showing first word of type)
    # Converts :trade_wind to "TRADE" for display
    # z: 202 ensures labels render above hand tiles
    tile_name = tile[:type].to_s.split('_').first.upcase
    args.outputs.labels << {
      x: rect[:x] + rect[:w] / 2,
      y: rect[:y] - 5,
      text: tile_name,
      size_px: 14,
      anchor_x: 0.5,
      anchor_y: 1.0,
      z: 202
    }
  end
end

