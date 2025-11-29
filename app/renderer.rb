# Renderer - Handles all drawing and visual output
#
# Core Concepts:
# - DragonRuby coordinates: (0,0) is bottom-left
# - Draw order matters: first drawn = behind
# - args.outputs.solids for filled rectangles
# - args.outputs.borders for outlines
# - args.outputs.labels for text
# - args.outputs.sprites for images (or primitives as sprites)
#
# Integration:
# - Called from main.rb at the end of each tick
# - Uses constants from loop_system.rb, tile_system.rb, input_handler.rb
# - Reads state from args.state to determine what to render

# Require systems for constants and helper functions
require 'app/loop_system.rb'
require 'app/tile_system.rb'
require 'app/input_handler.rb'

# Color definitions for each tile type
# Used when rendering tiles in slots and hand
# RGB values (0-255) for visual distinction between tile types
TILE_COLORS = {
  trade_wind: { r: 100, g: 200, b: 255 },  # light blue
  storm:      { r: 100, g: 100, b: 150 },  # purple-gray
  calm_water: { r: 150, g: 220, b: 180 },  # soft green
  wreckage:   { r: 139, g: 90,  b: 43  }   # brown
}

# Main render function - orchestrates all drawing operations
# Called each tick from main.rb, even when game is over
# Draw order is important: background first, UI elements last
# Args:
#   args - DragonRuby args object containing state and outputs
def render(args)
  render_background(args)
  render_loop_path(args)
  render_slots(args)
  render_ship(args)
  render_meters(args)
  render_hand(args)
  render_wave_effect(args)
  render_game_over(args) if args.state.game_over
  render_victory(args) if args.state.victory
end

# Renders the game background (solid color fill)
# Simple dark background to provide contrast for game elements
# Args:
#   args - DragonRuby args object
def render_background(args)
  # Full screen dark background (1280x720 default DragonRuby resolution)
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 20,
    g: 20,
    b: 30
  }
end

# Renders the circular loop path that the ship travels along
# Draws dots around the circle to visualize the path
# Uses the same center and radius constants as the ship movement
# Args:
#   args - DragonRuby args object
def render_loop_path(args)
  # Draw 36 dots evenly spaced around the circle to show the path
  36.times do |i|
    # Calculate angle for this dot (evenly distributed around full circle)
    angle = (i / 36.0) * TWO_PI

    # Convert polar coordinates to cartesian (same formula as ship_position)
    x = LOOP_CENTER_X + LOOP_RADIUS * Math.cos(angle)
    y = LOOP_CENTER_Y + LOOP_RADIUS * Math.sin(angle)

    # Draw small dot (4x4 pixels) at this position
    args.outputs.solids << {
      x: x - 2,
      y: y - 2,
      w: 4,
      h: 4,
      r: 80,
      g: 80,
      b: 80
    }
  end
end

# Renders all 12 slots around the loop circle
# Shows empty slots as outlines, occupied slots as filled colored rectangles
# Args:
#   args - DragonRuby args object
def render_slots(args)
  SLOT_COUNT.times do |i|
    # Get collision rectangle for this slot (used for positioning)
    rect = slot_rect(i)
    tile = args.state.loop_slots[i]

    if tile
      # Slot has a tile - draw filled rectangle with tile's color
      color = TILE_COLORS[tile[:type]]
      args.outputs.solids << rect.merge(color)
    else
      # Slot is empty - draw outline only
      args.outputs.borders << rect.merge(r: 100, g: 100, b: 100)
    end
  end
end

# Renders the ship at its current position on the loop
# Simple triangle/square representation of the ship
# Position calculated from ship_angle using ship_position helper
# Args:
#   args - DragonRuby args object
def render_ship(args)
  # Get ship position from current angle
  pos = ship_position(args.state.ship_angle)

  # Draw simple square ship (30x30 pixels, white)
  # TODO: Could be enhanced with triangle or sprite later
  args.outputs.solids << {
    x: pos[:x] - 15,
    y: pos[:y] - 15,
    w: 30,
    h: 30,
    r: 255,
    g: 255,
    b: 255
  }
end

# Renders the Hold and Wind meters at the top of the screen
# Hold meter (red) on left, Wind meter (blue) on right
# Shows current value as filled bar and text label
# Args:
#   args - DragonRuby args object
def render_meters(args)
  # Hold meter (red, top-left)
  # Background bar (gray, full width)
  args.outputs.solids << {
    x: 50,
    y: 650,
    w: 200,
    h: 30,
    r: 50,
    g: 50,
    b: 50
  }

  # Filled portion based on hold value (0-100)
  hold_width = (args.state.hold / 100.0) * 200
  args.outputs.solids << {
    x: 50,
    y: 650,
    w: hold_width,
    h: 30,
    r: 200,
    g: 50,
    b: 50
  }

  # Label showing current hold value
  args.outputs.labels << {
    x: 150,
    y: 695,
    text: "HOLD: #{args.state.hold.to_i}",
    anchor_x: 0.5,
    anchor_y: 0.5
  }

  # Wind meter (blue, top-right)
  # Background bar (gray, full width)
  args.outputs.solids << {
    x: 1030,
    y: 650,
    w: 200,
    h: 30,
    r: 50,
    g: 50,
    b: 50
  }

  # Filled portion based on wind value (0-100)
  wind_width = (args.state.wind / 100.0) * 200
  args.outputs.solids << {
    x: 1030,
    y: 650,
    w: wind_width,
    h: 30,
    r: 50,
    g: 100,
    b: 200
  }

  # Label showing current wind value
  args.outputs.labels << {
    x: 1130,
    y: 695,
    text: "WIND: #{args.state.wind.to_i}",
    anchor_x: 0.5,
    anchor_y: 0.5
  }
end

# Renders the player's hand (3 tiles at bottom of screen)
# Shows each tile with its color and name
# Highlights the selected tile with a yellow border
# Args:
#   args - DragonRuby args object
def render_hand(args)
  args.state.hand.each_with_index do |tile, i|
    # Get collision rectangle for this hand tile
    rect = hand_tile_rect(i)

    # Draw filled tile with its type's color
    color = TILE_COLORS[tile[:type]]
    args.outputs.solids << rect.merge(color)

    # Highlight selected tile with yellow border (thicker, offset)
    if args.state.selected_tile == i
      args.outputs.borders << {
        x: rect[:x] - 2,
        y: rect[:y] - 2,
        w: rect[:w] + 4,
        h: rect[:h] + 4,
        r: 255,
        g: 255,
        b: 0
      }
    end

    # Tile name label (below tile, showing first word of type)
    # Converts :trade_wind to "TRADE" for display
    tile_name = tile[:type].to_s.split('_').first.upcase
    args.outputs.labels << {
      x: rect[:x] + rect[:w] / 2,
      y: rect[:y] - 5,
      text: tile_name,
      size_px: 14,
      anchor_x: 0.5,
      anchor_y: 1.0
    }
  end
end

# Renders wave effect visual feedback when a wave destroys a tile
# Shows a screen flash or overlay when wave_active flag is set
# Decrements wave_active each frame until it reaches 0
# Args:
#   args - DragonRuby args object
def render_wave_effect(args)
  return unless args.state.wave_active && args.state.wave_active > 0

  # Draw semi-transparent overlay to indicate wave event
  # Alpha value decreases as wave_active approaches 0
  alpha = (args.state.wave_active / 30.0 * 100).to_i
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 100,
    g: 150,
    b: 255,
    a: alpha
  }

  # Decrement wave_active counter (30 frames = ~0.5 seconds at 60fps)
  args.state.wave_active -= 1
end

# Renders game over overlay when hold meter reaches 100
# Shows message and restart instruction
# Args:
#   args - DragonRuby args object
def render_game_over(args)
  # Semi-transparent dark overlay
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 0,
    g: 0,
    b: 0,
    a: 180
  }

  # Game over message
  args.outputs.labels << {
    x: 640,
    y: 400,
    text: "GAME OVER",
    size_px: 72,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 200,
    g: 50,
    b: 50
  }

  # Restart instruction
  args.outputs.labels << {
    x: 640,
    y: 300,
    text: "Press R to Restart",
    size_px: 24,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 200,
    g: 200,
    b: 200
  }
end

# Renders victory overlay when wind meter reaches 100
# Shows message and restart instruction
# Args:
#   args - DragonRuby args object
def render_victory(args)
  # Semi-transparent light overlay
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 0,
    g: 0,
    b: 0,
    a: 180
  }

  # Victory message
  args.outputs.labels << {
    x: 640,
    y: 400,
    text: "VICTORY!",
    size_px: 72,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 50,
    g: 200,
    b: 255
  }

  # Restart instruction
  args.outputs.labels << {
    x: 640,
    y: 300,
    text: "Press R to Restart",
    size_px: 24,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 200,
    g: 200,
    b: 200
  }
end

