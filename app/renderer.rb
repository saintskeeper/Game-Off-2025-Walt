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
# - Uses graph_system.rb, navigation_system.rb, tile_system.rb
# - Reads state from args.state to determine what to render

# Require systems for constants and helper functions
require 'app/graph_system.rb'
require 'app/navigation_system.rb'
require 'app/tile_system.rb'
require 'app/input_handler.rb'
require 'app/hud/hud_system.rb'
# Note: TILE_COLORS is now defined in tile_system.rb for shared access

# Main render function - orchestrates all drawing operations
# Called each tick from main.rb, even when game is over
# Draw order is important: background first, UI elements last
# Args:
#   args - DragonRuby args object containing state and outputs
def render(args)
  render_background(args)
  render_graph_edges(args)
  render_graph_nodes(args)
  render_available_choices(args)
  render_ship(args)
  render_meters(args)
  render_hand(args)
  render_wave_effect(args)
  render_game_over(args) if args.state.game_over
  render_victory(args) if args.state.victory
end

# Renders the game background using the world map sprite
# Changed from static_sprites to regular sprites to ensure proper z-index ordering
# static_sprites render in a separate pass and can appear on top regardless of z-index
# Sets z: 0 to ensure it renders behind all game objects
# Args:
#   args - DragonRuby args object
def render_background(args)
  args.outputs.sprites << {
    x: 0,
    y: 0,
    w: args.grid.w,
    h: args.grid.h,
    path: 'sprites/hud/world-map/world-map_export.png',
    z: 0
  }
end

# Renders all graph edges as lines with slot markers
# Draws connections between nodes and visualizes tile slots along edges
# Args:
#   args - DragonRuby args object
def render_graph_edges(args)
  PATH_EDGES.each do |edge|
    from_node = PATH_NODES[edge[:from]]
    to_node = PATH_NODES[edge[:to]]

    # Draw edge path
    # z: 1 ensures edges render above background (z: 0) but below nodes and ship
    if edge[:path] && edge[:path].length > 1
      # Draw pathfound route as connected line segments
      edge[:path].each_cons(2) do |point_a, point_b|
        args.outputs.lines << {
          x: point_a[:x],
          y: point_a[:y],
          x2: point_b[:x],
          y2: point_b[:y],
          r: 100,
          g: 120,
          b: 140,
          z: 1
        }
      end
    else
      # Fallback to straight line
      args.outputs.lines << {
        x: from_node[:position][:x],
        y: from_node[:position][:y],
        x2: to_node[:position][:x],
        y2: to_node[:position][:y],
        r: 100,
        g: 120,
        b: 140,
        z: 1
      }
    end

    # Draw slots along this edge
    edge[:slots].times do |i|
      pos = edge_slot_position(edge[:id], i)
      tile = edge[:tiles][i]

      if tile
        # Slot has a tile - draw the tile icon sprite
        # z: 5 ensures tile icons render above map background but below ship
        icon_path = TILE_ICON_SPRITES[tile[:type]]
        if icon_path
          args.outputs.sprites << {
            x: pos[:x] - 20,
            y: pos[:y] - 20,
            w: 40,
            h: 40,
            path: icon_path,
            z: 5
          }
        else
          # Fallback to colored rectangle
          # z: 5 ensures tile icons render above map background but below ship
          color = TILE_COLORS[tile[:type]]
          args.outputs.solids << {
            x: pos[:x] - 20,
            y: pos[:y] - 20,
            w: 40,
            h: 40,
            z: 5
          }.merge(color)
        end
      else
        # Slot is empty - draw outline only
        # z: 5 ensures empty slot borders render above map background but below ship
        args.outputs.borders << {
          x: pos[:x] - 20,
          y: pos[:y] - 20,
          w: 40,
          h: 40,
          r: 80,
          g: 80,
          b: 80,
          z: 5
        }
      end
    end
  end
end

# Renders waypoint nodes as circles with labels
# Shows connection points between edges
# Args:
#   args - DragonRuby args object
def render_graph_nodes(args)
  PATH_NODES.each do |node_id, node|
    # Draw node circle
    # z: 2 ensures nodes render above edges (z: 1) but below ship (z: 100)
    args.outputs.solids << {
      x: node[:position][:x] - 8,
      y: node[:position][:y] - 8,
      w: 16,
      h: 16,
      r: 150,
      g: 150,
      b: 200,
      z: 2
    }

    # Draw node label if present
    # z: 2 ensures labels render with their corresponding nodes
    if node[:metadata][:name]
      args.outputs.labels << {
        x: node[:position][:x],
        y: node[:position][:y] - 20,
        text: node[:metadata][:name],
        size_px: 14,
        alignment_enum: 1,  # center
        z: 2
      }
    end
  end
end

# Highlights clickable nodes at branch points
# Shows pulsing indicator for available path choices
# Args:
#   args - DragonRuby args object
def render_available_choices(args)
  next_edges = get_next_edge_choices(args.state)
  return if next_edges.empty?

  next_edges.each do |edge|
    to_node = PATH_NODES[edge[:to]]

    # Pulsing highlight effect
    # z: 3 ensures choice highlights render above nodes (z: 2) but below ship (z: 100)
    pulse = (Math.sin(args.state.tick_count * 0.1) * 30 + 70).to_i
    args.outputs.borders << {
      x: to_node[:position][:x] - 12,
      y: to_node[:position][:y] - 12,
      w: 24,
      h: 24,
      r: 100,
      g: 255,
      b: 100,
      a: pulse,
      z: 3
    }
  end
end

# Renders the ship at its current position on the graph
# Uses sprite image for visual representation
# Position calculated from ship state using ship_screen_position helper
# Sets z: 10 to ensure it renders above the map background
# Args:
#   args - DragonRuby args object
def render_ship(args)
  # Get ship position from current edge and progress
  pos = ship_screen_position(args.state)

  # Draw ship sprite (64x64 pixels, centered on position)
  # Sprite path: sprites/hud/ships/base-ship.png
  # z: 100 ensures ship renders above map background and all map elements
  # Using high z value to ensure it appears above static_sprites background
  args.outputs.sprites << {
    x: pos[:x] - 32,
    y: pos[:y] - 32,
    w: 64,
    h: 64,
    path: 'sprites/hud/ships/base-ship.png',
    z: 100
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
  # z: 150 ensures meters render above ship (z: 100) but below HUD hand (z: 200)
  args.outputs.solids << {
    x: 50,
    y: 650,
    w: 200,
    h: 30,
    r: 50,
    g: 50,
    b: 50,
    z: 150
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
    b: 50,
    z: 151
  }

  # Label showing current hold value
  args.outputs.labels << {
    x: 150,
    y: 695,
    text: "HOLD: #{args.state.hold.to_i}",
    anchor_x: 0.5,
    anchor_y: 0.5,
    z: 152
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
    b: 50,
    z: 150
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
    b: 200,
    z: 151
  }

  # Label showing current wind value
  args.outputs.labels << {
    x: 1130,
    y: 695,
    text: "WIND: #{args.state.wind.to_i}",
    anchor_x: 0.5,
    anchor_y: 0.5,
    z: 152
  }
end

# Hand rendering is now handled by hud_system.rb
# The render_hand function has been moved to hud_system.rb for better organization
# It is called directly from there when renderer.rb calls render_hand(args)

# Renders wave effect visual feedback when a wave destroys a tile
# Shows a screen flash or overlay when wave_active flag is set
# Decrements wave_active each frame until it reaches 0
# Args:
#   args - DragonRuby args object
def render_wave_effect(args)
  return unless args.state.wave_active && args.state.wave_active > 0

  # Draw semi-transparent overlay to indicate wave event
  # Alpha value decreases as wave_active approaches 0
  # z: 250 ensures wave effect renders above HUD (z: 200) but below game over/victory (z: 300)
  alpha = (args.state.wave_active / 30.0 * 100).to_i
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 100,
    g: 150,
    b: 255,
    a: alpha,
    z: 250
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
  # z: 300 ensures game over overlay renders above everything else
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 0,
    g: 0,
    b: 0,
    a: 180,
    z: 300
  }

  # Game over message
  # z: 301 ensures message renders above overlay
  args.outputs.labels << {
    x: 640,
    y: 400,
    text: "GAME OVER",
    size_px: 72,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 200,
    g: 50,
    b: 50,
    z: 301
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
    b: 200,
    z: 301
  }
end

# Renders victory overlay when wind meter reaches 100
# Shows message and restart instruction
# Args:
#   args - DragonRuby args object
def render_victory(args)
  # Semi-transparent light overlay
  # z: 300 ensures victory overlay renders above everything else
  args.outputs.solids << {
    x: 0,
    y: 0,
    w: 1280,
    h: 720,
    r: 0,
    g: 0,
    b: 0,
    a: 180,
    z: 300
  }

  # Victory message
  # z: 301 ensures message renders above overlay
  args.outputs.labels << {
    x: 640,
    y: 400,
    text: "VICTORY!",
    size_px: 72,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 50,
    g: 200,
    b: 255,
    z: 301
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
    b: 200,
    z: 301
  }
end

