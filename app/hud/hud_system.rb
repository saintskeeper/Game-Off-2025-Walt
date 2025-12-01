# HUD System - Handles rendering of Heads-Up Display elements
#
# Core Concepts:
# - Handles player hand rendering with sprites
# - Handles cargo hold rendering (4 slots for found items)
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

# Cargo hold positioning constants
CARGO_START_X = 880  # Right side of screen
CARGO_Y = 50         # Same Y as hand
CARGO_SLOT_SIZE = 60 # Slightly smaller than hand tiles
CARGO_SPACING = 70   # Spacing between cargo slots

# Cargo type display info
CARGO_DISPLAY = {
  cargo_rum: { name: "RUM", color: { r: 139, g: 69, b: 19 } },      # Brown
  cargo_spices: { name: "SPICE", color: { r: 255, g: 165, b: 0 } }, # Orange
  cargo_gold: { name: "GOLD", color: { r: 255, g: 215, b: 0 } },    # Gold
  cargo_tobacco: { name: "LEAF", color: { r: 34, g: 139, b: 34 } }  # Green
}

# Renders the player's hand (3 tiles at bottom of screen)
# Uses sprite backgrounds with tile type icons in the center
# Highlights the selected tile with a yellow border
# Uses primitives collection for consistent z-index ordering
# Args:
#   args - DragonRuby args object containing state and outputs
def render_hand(args)
  args.state.hand.each_with_index do |tile, i|
    # Get collision rectangle for this hand tile (positioning from input_handler)
    rect = hand_tile_rect(i)

    # Draw sprite background for the tile using primitives for z-ordering
    args.outputs.primitives << {
      x: rect[:x],
      y: rect[:y],
      w: rect[:w],
      h: rect[:h],
      path: HAND_TILE_SPRITE,
      z: 120  # ZIndex::HAND_BG
    }

    # Draw tile type icon in the center of the sprite
    icon_path = TILE_ICON_SPRITES[tile[:type]]
    if icon_path
      # Calculate center position for the icon
      center_x = rect[:x] + (rect[:w] / 2) - (ICON_SIZE / 2)
      center_y = rect[:y] + (rect[:h] / 2) - (ICON_SIZE / 2)

      # Draw the tile type icon sprite centered on the background sprite
      args.outputs.primitives << {
        x: center_x,
        y: center_y,
        w: ICON_SIZE,
        h: ICON_SIZE,
        path: icon_path,
        z: 121  # ZIndex::HAND_ICON
      }
    end

    # Highlight selected tile with yellow border (thicker, offset)
    if args.state.selected_tile == i
      args.outputs.primitives << {
        x: rect[:x] - 2,
        y: rect[:y] - 2,
        w: rect[:w] + 4,
        h: rect[:h] + 4,
        r: 255,
        g: 255,
        b: 0,
        z: 122,  # ZIndex::HAND_SELECTION
        primitive_marker: :border
      }
    end

    # Tile name label (below tile, showing first word of type)
    tile_name = tile[:type].to_s.split('_').first.upcase
    args.outputs.primitives << {
      x: rect[:x] + rect[:w] / 2,
      y: rect[:y] - 5,
      text: tile_name,
      size_px: 14,
      anchor_x: 0.5,
      anchor_y: 1.0,
      z: 122  # ZIndex::HAND_SELECTION (same layer as selection border)
    }
  end
end

# Renders the cargo hold (4 slots at bottom right of screen)
# Shows items collected from islands on the return journey
# Args:
#   args - DragonRuby args object containing state and outputs
def render_cargo_hold(args)
  # Initialize cargo hold if not present
  args.state.cargo_hold ||= Array.new(4, nil)

  # Label for cargo hold section
  args.outputs.primitives << {
    x: CARGO_START_X + (CARGO_SPACING * 1.5),
    y: CARGO_Y + CARGO_SLOT_SIZE + 20,
    text: "CARGO HOLD",
    size_px: 14,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 200, g: 200, b: 200,
    z: 120
  }

  # Render each cargo slot
  4.times do |i|
    slot_x = CARGO_START_X + (i * CARGO_SPACING)
    cargo = args.state.cargo_hold[i]

    # Draw slot background (darker for empty, lighter for filled)
    if cargo
      # Filled slot - use cargo type color
      display_info = CARGO_DISPLAY[cargo[:type]] || { name: "?", color: { r: 100, g: 100, b: 100 } }
      color = display_info[:color]

      args.outputs.primitives << {
        x: slot_x,
        y: CARGO_Y,
        w: CARGO_SLOT_SIZE,
        h: CARGO_SLOT_SIZE,
        path: :solid,
        r: color[:r], g: color[:g], b: color[:b], a: 200,
        z: 120
      }

      # Border
      args.outputs.primitives << {
        x: slot_x,
        y: CARGO_Y,
        w: CARGO_SLOT_SIZE,
        h: CARGO_SLOT_SIZE,
        r: 255, g: 215, b: 0,  # Gold border for filled
        z: 121,
        primitive_marker: :border
      }

      # Cargo type name
      args.outputs.primitives << {
        x: slot_x + CARGO_SLOT_SIZE / 2,
        y: CARGO_Y + CARGO_SLOT_SIZE / 2 + 10,
        text: display_info[:name],
        size_px: 12,
        anchor_x: 0.5,
        anchor_y: 0.5,
        r: 255, g: 255, b: 255,
        z: 122
      }

      # Cargo value
      args.outputs.primitives << {
        x: slot_x + CARGO_SLOT_SIZE / 2,
        y: CARGO_Y + CARGO_SLOT_SIZE / 2 - 10,
        text: cargo[:value].to_s,
        size_px: 14,
        anchor_x: 0.5,
        anchor_y: 0.5,
        r: 255, g: 255, b: 255,
        z: 122
      }
    else
      # Empty slot - darker background
      args.outputs.primitives << {
        x: slot_x,
        y: CARGO_Y,
        w: CARGO_SLOT_SIZE,
        h: CARGO_SLOT_SIZE,
        path: :solid,
        r: 40, g: 40, b: 50, a: 150,
        z: 120
      }

      # Border
      args.outputs.primitives << {
        x: slot_x,
        y: CARGO_Y,
        w: CARGO_SLOT_SIZE,
        h: CARGO_SLOT_SIZE,
        r: 80, g: 80, b: 90,
        z: 121,
        primitive_marker: :border
      }
    end
  end
end

