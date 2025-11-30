# Renderer - Handles all drawing and visual output
#
# Core Concepts:
# - DragonRuby coordinates: (0,0) is bottom-left
# - All rendering uses args.outputs.primitives for consistent z-index ordering
# - Z-index determines draw order across ALL primitive types
#
# Integration:
# - Called from main.rb at the end of each tick
# - Uses graph_system.rb, navigation_system.rb, tile_system.rb
# - Reads state from args.state to determine what to render

# Z-Index Layer Organization
# Organized by render order (bottom to top)
module ZIndex
  # Map layer
  BACKGROUND = 0
  EDGES = 1
  NODES = 2
  CHOICES = 3
  TILE_SLOTS = 5

  # Dynamic game objects
  SHIP = 100

  # HUD layer
  METERS_BG = 110
  METERS_FILL = 111
  METERS_LABEL = 112
  HAND_BG = 120
  HAND_ICON = 121
  HAND_SELECTION = 122

  # Effects and overlays
  WAVE_EFFECT = 200
  GAME_OVER = 300
  GAME_OVER_TEXT = 301
end

# Background sprite path constant
WORLD_MAP_SPRITE = 'sprites/hud/world-map/world-map_export.png'

# Require systems for constants and helper functions
require 'app/graph_system.rb'
require 'app/navigation_system.rb'
require 'app/tile_system.rb'
require 'app/input_handler.rb'
require 'app/hud/hud_system.rb'
require 'app/helpers/rendering_helpers.rb'

# Main render function - orchestrates all drawing operations
# Called each tick from main.rb, even when game is over
# Draw order is important: background first, UI elements last
# All primitives use args.outputs.primitives for consistent z-index ordering
# Args:
#   args - DragonRuby args object containing state and outputs
def render(args)
  # Render background
  render_background(args)

  # Render graph elements
  render_graph_edges(args)
  render_graph_nodes(args)

  # Render dynamic elements
  render_available_choices(args)
  render_ship(args)
  render_meters(args)
  render_hand(args)
  render_wave_effect(args)
  render_game_over(args) if args.state.game_over
  render_victory(args) if args.state.victory
end

# Renders the world map background using static_sprites
# static_sprites persist until explicitly cleared - no flicker
def render_background(args)
  # Only add to static_sprites once
  unless args.state.background_rendered
    args.outputs.static_sprites << {
      x: 0,
      y: 0,
      w: 1280,
      h: 720,
      path: WORLD_MAP_SPRITE
    }
    args.state.background_rendered = true
    puts "[RENDER] Background added to static_sprites"
  end
end

# Renders graph edges as lines with tile slots
# Lines are rendered once to static_lines for performance
# Tile slots are rendered dynamically each frame as they can change
# Lines are red and dotted like a treasure map
def render_graph_edges(args)
  # Render edge path lines once to static_lines (they don't change)
  unless args.state.edges_rendered
    args.state.path_edges.each do |edge|
      from_node = args.state.path_nodes[edge[:from]]
      to_node = args.state.path_nodes[edge[:to]]

      # Draw edge path lines as red dotted lines (treasure map style)
      if edge[:path] && edge[:path].length > 1
        edge[:path].each_cons(2) do |point_a, point_b|
          # Create dotted line segments for this path segment
          dotted_segments = create_dotted_line(
            point_a[:x], point_a[:y],
            point_b[:x], point_b[:y]
          )
          # Add all dot segments to static_lines
          dotted_segments.each do |segment|
            args.outputs.static_lines << segment
          end
        end
      else
        # Fallback: straight dotted line between nodes
        dotted_segments = create_dotted_line(
          from_node[:position][:x], from_node[:position][:y],
          to_node[:position][:x], to_node[:position][:y]
        )
        dotted_segments.each do |segment|
          args.outputs.static_lines << segment
        end
      end
    end
    args.state.edges_rendered = true
    puts "[RENDER] Red dotted edge lines added to static_lines (treasure map style)"
  end

  # Draw tile slots along edge (rendered dynamically each frame)
  args.state.path_edges.each do |edge|
    edge[:slots].times do |i|
      pos = edge_slot_position(args.state, edge[:id], i)
      tile = edge[:tiles][i]

      if tile
        icon_path = TILE_ICON_SPRITES[tile[:type]]
        if icon_path
          args.outputs.primitives << {
            x: pos[:x] - 20, y: pos[:y] - 20,
            w: 40, h: 40,
            path: icon_path,
            z: ZIndex::TILE_SLOTS
          }
        else
          color = TILE_COLORS[tile[:type]]
          args.outputs.primitives << {
            x: pos[:x] - 20, y: pos[:y] - 20,
            w: 40, h: 40,
            path: :solid,
            z: ZIndex::TILE_SLOTS
          }.merge(color)
        end
      else
        args.outputs.primitives << {
          x: pos[:x] - 20, y: pos[:y] - 20,
          w: 40, h: 40,
          r: 80, g: 80, b: 80,
          z: ZIndex::TILE_SLOTS,
          primitive_marker: :border
        }
      end
    end
  end
end

# Renders graph nodes as squares with labels
def render_graph_nodes(args)
  args.state.path_nodes.each do |node_id, node|
    args.outputs.primitives << {
      x: node[:position][:x] - 8,
      y: node[:position][:y] - 8,
      w: 16, h: 16,
      r: 150, g: 150, b: 200,
      path: :solid,
      z: ZIndex::NODES
    }

    if node[:metadata][:name]
      args.outputs.primitives << {
        x: node[:position][:x],
        y: node[:position][:y] - 20,
        text: node[:metadata][:name],
        size_px: 14,
        alignment_enum: 1,
        z: ZIndex::NODES
      }
    end
  end
end

# Highlights clickable nodes with pulsing border
def render_available_choices(args)
  next_edges = get_next_edge_choices(args.state)
  return if next_edges.empty?

  pulse = (Math.sin(Kernel.tick_count * 0.1) * 30 + 70).to_i

  next_edges.each do |edge|
    to_node = args.state.path_nodes[edge[:to]]
    args.outputs.primitives << {
      x: to_node[:position][:x] - 12,
      y: to_node[:position][:y] - 12,
      w: 24, h: 24,
      r: 100, g: 255, b: 100,
      a: pulse,
      z: ZIndex::CHOICES,
      primitive_marker: :border
    }
  end
end

# Renders the ship sprite
def render_ship(args)
  pos = ship_screen_position(args.state)
  args.outputs.primitives << args.state.ship_sprite_base.merge({
    x: pos[:x] - 32,
    y: pos[:y] - 32
  })
end

# Renders Hold and Wind meters
def render_meters(args)
  # Hold meter background
  args.outputs.primitives << args.state.hold_meter_bg

  # Hold meter fill
  hold_width = (args.state.hold / 100.0) * 200
  args.outputs.primitives << {
    x: 50, y: 650, w: hold_width, h: 30,
    r: 200, g: 50, b: 50,
    path: :solid,
    z: ZIndex::METERS_FILL
  }

  # Hold label
  args.outputs.primitives << {
    x: 150, y: 695,
    text: "HOLD: #{args.state.hold.to_i}",
    anchor_x: 0.5, anchor_y: 0.5,
    z: ZIndex::METERS_LABEL
  }

  # Wind meter background
  args.outputs.primitives << args.state.wind_meter_bg

  # Wind meter fill
  wind_width = (args.state.wind / 100.0) * 200
  args.outputs.primitives << {
    x: 1030, y: 650, w: wind_width, h: 30,
    r: 50, g: 100, b: 200,
    path: :solid,
    z: ZIndex::METERS_FILL
  }

  # Wind label
  args.outputs.primitives << {
    x: 1130, y: 695,
    text: "WIND: #{args.state.wind.to_i}",
    anchor_x: 0.5, anchor_y: 0.5,
    z: ZIndex::METERS_LABEL
  }
end

# Renders wave effect overlay
def render_wave_effect(args)
  return unless args.state.wave_active && args.state.wave_active > 0

  alpha = (args.state.wave_active / 30.0 * 100).to_i
  args.outputs.primitives << {
    x: 0, y: 0, w: 1280, h: 720,
    r: 100, g: 150, b: 255, a: alpha,
    path: :solid,
    z: ZIndex::WAVE_EFFECT
  }
  args.state.wave_active -= 1
end

# Renders game over overlay
def render_game_over(args)
  args.outputs.primitives << {
    x: 0, y: 0, w: 1280, h: 720,
    r: 0, g: 0, b: 0, a: 180,
    path: :solid,
    z: ZIndex::GAME_OVER
  }

  args.outputs.primitives << {
    x: 640, y: 400,
    text: "GAME OVER",
    size_px: 72,
    anchor_x: 0.5, anchor_y: 0.5,
    r: 200, g: 50, b: 50,
    z: ZIndex::GAME_OVER_TEXT
  }

  args.outputs.primitives << {
    x: 640, y: 300,
    text: "Press R to Restart",
    size_px: 24,
    anchor_x: 0.5, anchor_y: 0.5,
    r: 200, g: 200, b: 200,
    z: ZIndex::GAME_OVER_TEXT
  }
end

# Renders victory overlay
def render_victory(args)
  args.outputs.primitives << {
    x: 0, y: 0, w: 1280, h: 720,
    r: 0, g: 0, b: 0, a: 180,
    path: :solid,
    z: ZIndex::GAME_OVER
  }

  args.outputs.primitives << {
    x: 640, y: 400,
    text: "VICTORY!",
    size_px: 72,
    anchor_x: 0.5, anchor_y: 0.5,
    r: 50, g: 200, b: 255,
    z: ZIndex::GAME_OVER_TEXT
  }

  args.outputs.primitives << {
    x: 640, y: 300,
    text: "Press R to Restart",
    size_px: 24,
    anchor_x: 0.5, anchor_y: 0.5,
    r: 200, g: 200, b: 200,
    z: ZIndex::GAME_OVER_TEXT
  }
end
