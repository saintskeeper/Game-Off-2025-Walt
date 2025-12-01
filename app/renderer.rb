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
  CANNON = 123

  # Effects and overlays
  WAVE_EFFECT = 200
  GAME_OVER = 300
  GAME_OVER_TEXT = 301
end

# Background sprite path constant
WORLD_MAP_SPRITE = 'sprites/hud/world-map/world-map_export.png'

# Render version - increment to force static re-render on hot reload
RENDER_VERSION = 4

# Require systems for constants and helper functions
require 'app/graph_system.rb'
require 'app/navigation_system.rb'
require 'app/tile_system.rb'
require 'app/input_handler.rb'
require 'app/hud/hud_system.rb'
require 'app/hud/edge_system.rb'
require 'app/helpers/rendering_helpers.rb'
require 'app/encounter_system/encounter_system.rb'

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
  # Node grid squares disabled - islands are waypoints, not tile placement areas
  # render_node_grid_squares(args)

  # Render dynamic elements
  render_available_choices(args)
  render_ship(args)
  render_meters(args)
  render_hand(args)
  render_cargo_hold(args)  # Render cargo hold (4 slots for found items)
  render_cannon(args)
  render_wave_effect(args)
  render_encounter_popup(args)  # Render encounter popup overlay
  render_game_over(args) if args.state.game_over
  render_victory(args) if args.state.victory
end

# Renders the world map background using static_sprites
# static_sprites persist until explicitly cleared - no flicker
def render_background(args)
  # Check if we need to re-render (first time or version changed)
  needs_render = !args.state.background_rendered || args.state.render_version != RENDER_VERSION

  if needs_render
    # Clear any old static rendering first (helps with hot reload)
    args.outputs.static_sprites.clear
    args.outputs.static_lines.clear

    args.outputs.static_sprites << {
      x: 0,
      y: 0,
      w: 1280,
      h: 720,
      path: WORLD_MAP_SPRITE
    }
    args.state.background_rendered = true
    args.state.render_version = RENDER_VERSION
    args.state.edges_rendered = false  # Force re-render of edges
    puts "[RENDER] Background added to static_sprites (version #{RENDER_VERSION})"
  end
end

# Renders graph edges as lines with tile slots
# Only renders the CURRENT edge path (not all edges)
# Lines are red and dotted like a treasure map
def render_graph_edges(args)
  # Get current edge - only render this path
  current_edge = get_current_edge(args.state)

  # Render current edge path dynamically (changes when ship moves to new edge)
  if current_edge && current_edge[:path] && current_edge[:path].length > 1
    current_edge[:path].each_cons(2) do |point_a, point_b|
      dotted_segments = create_dotted_line(
        point_a[:x], point_a[:y],
        point_b[:x], point_b[:y]
      )
      dotted_segments.each do |segment|
        args.outputs.primitives << segment.merge(z: ZIndex::EDGES)
      end
    end
  end

  # Draw tile slots along edge (rendered dynamically each frame)
  # This renders the squares the player moves through
  render_edge_tile_slots(args, ZIndex::TILE_SLOTS)
end

# Renders graph nodes as visible markers
# Only renders the START and END ports - not all nodes
def render_graph_nodes(args)
  # Only render start and end ports
  start_node = args.state.path_nodes[args.state.start_node]
  end_node = args.state.path_nodes[args.state.end_node]

  [start_node, end_node].compact.each do |node|
    next unless node[:type] == :port

    # Ports: larger visible marker
    node_size = 32
    half_size = node_size / 2

    # Background
    args.outputs.primitives << {
      x: node[:position][:x] - half_size,
      y: node[:position][:y] - half_size,
      w: node_size, h: node_size,
      r: 60, g: 50, b: 40, a: 220,
      path: :solid,
      z: ZIndex::NODES
    }

    # Border - warm brown
    args.outputs.primitives << {
      x: node[:position][:x] - half_size,
      y: node[:position][:y] - half_size,
      w: node_size, h: node_size,
      r: 160, g: 130, b: 80, a: 255,
      z: ZIndex::NODES + 1,
      primitive_marker: :border
    }

    # Port label - larger and offset below node
    if node[:metadata] && node[:metadata][:name]
      args.outputs.primitives << {
        x: node[:position][:x],
        y: node[:position][:y] - half_size - 8,
        text: node[:metadata][:name],
        size_px: 14,
        anchor_x: 0.5,
        anchor_y: 1.0,
        r: 255, g: 240, b: 200,
        z: ZIndex::NODES + 1
      }
    end
  end
end

# Renders grid squares on islands and ports where tiles can be placed
# Similar to edge tile slots, but positioned on the navigation grid
# Rendered dynamically each frame as tiles can be placed/removed
# Args:
#   args - DragonRuby args object containing state and outputs
def render_node_grid_squares(args)
  args.state.path_nodes.each do |node_id, node|
    # Only render grid squares for nodes that have them (islands and ports)
    next unless node[:grid_squares] && node[:grid_squares].length > 0

    # Initialize tiles array for this node if it doesn't exist
    # This stores which tiles are placed on which grid squares
    args.state.node_tiles ||= {}
    args.state.node_tiles[node_id] ||= Array.new(node[:grid_squares].length, nil)

    node[:grid_squares].each_with_index do |grid_square, i|
      pos = node_grid_square_position(args.state, node_id, i)
      tile = args.state.node_tiles[node_id][i]

      if tile
        # Render tile icon or colored square if tile is placed
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
        # Render empty grid square as gray border (similar to edge slots)
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

# Highlights clickable nodes with pulsing border
def render_available_choices(args)
  next_edges = get_next_edge_choices(args.state)
  return if next_edges.empty?

  pulse = (Math.sin(Kernel.tick_count * 0.15) * 40 + 100).to_i

  next_edges.each do |edge|
    to_node = args.state.path_nodes[edge[:to]]
    # Larger highlight to match new 32x32 node size (36x36 for visibility)
    args.outputs.primitives << {
      x: to_node[:position][:x] - 18,
      y: to_node[:position][:y] - 18,
      w: 36, h: 36,
      r: 100, g: 255, b: 100,
      a: pulse,
      z: ZIndex::CHOICES,
      primitive_marker: :border
    }
  end
end

# Renders the ship sprite
# Ship sprite is 64x64 at normal size
# Centered on tile slot squares (tile slots are 40x40, centered on pos)
# Ship position comes from ship_screen_position which returns the center of the current tile slot
# Ship is centered both horizontally and vertically on the tile slot position
def render_ship(args)
  pos = ship_screen_position(args.state)

  # Flip ship sprite horizontally if on return journey
  flip = args.state.ship[:journey_phase] == :return

  args.outputs.primitives << args.state.ship_sprite_base.merge({
    x: pos[:x] - 32,  # Center horizontally: ship width is 64, so offset by half (32)
    y: pos[:y] - 32,  # Center vertically: ship height is 64, so offset by half (32)
    flip_horizontally: flip
  })
end

# Renders Hold and Cargo meters
def render_meters(args)
  # Hull Integrity meter - rendered using ship-health sprite
  # Sprite is displayed at native size (256x128) on left side, aligned with cargo meter at top
  args.outputs.primitives << args.state.hold_meter_bg

  # Hull Integrity label - centered in the sprite
  # Calculate position relative to sprite - place text centered both horizontally and vertically
  sprite_x = args.state.hold_meter_bg[:x]
  sprite_y = args.state.hold_meter_bg[:y]
  sprite_w = args.state.hold_meter_bg[:w]
  sprite_h = args.state.hold_meter_bg[:h]
  # Position label at the center of the sprite
  # In DragonRuby, y is bottom-left, so sprite center = sprite_y + (sprite_h / 2)
  sprite_center_x = sprite_x + (sprite_w / 2)
  sprite_center_y = sprite_y + (sprite_h / 2)

  args.outputs.primitives << {
    x: sprite_center_x,  # Center of sprite horizontally
    y: sprite_center_y,  # Center of sprite vertically
    text: "Hull Integrity: #{args.state.hold.to_i}",
    anchor_x: 0.5, anchor_y: 0.5,  # Center anchor so text is perfectly centered
    r: 255, g: 255, b: 255,  # White text color
    z: ZIndex::METERS_LABEL  # Use same z-index as Wind label for consistency
  }

  # Cargo meter background - rendered using cargo-hud sprite
  # Sprite is displayed at native size (256x128) on right side, aligned with hull integrity meter at top
  args.outputs.primitives << args.state.wind_meter_bg

  # Cargo label - centered in the sprite
  # Calculate position relative to sprite - place text centered both horizontally and vertically
  cargo_sprite_x = args.state.wind_meter_bg[:x]
  cargo_sprite_y = args.state.wind_meter_bg[:y]
  cargo_sprite_w = args.state.wind_meter_bg[:w]
  cargo_sprite_h = args.state.wind_meter_bg[:h]
  # Position label at the center of the sprite
  # In DragonRuby, y is bottom-left, so sprite center = sprite_y + (sprite_h / 2)
  cargo_sprite_center_x = cargo_sprite_x + (cargo_sprite_w / 2)
  cargo_sprite_center_y = cargo_sprite_y + (cargo_sprite_h / 2)

  args.outputs.primitives << {
    x: cargo_sprite_center_x,  # Center of sprite horizontally
    y: cargo_sprite_center_y,  # Center of sprite vertically
    text: "CARGO: #{args.state.wind.to_i}",
    anchor_x: 0.5, anchor_y: 0.5,  # Center anchor so text is perfectly centered
    r: 255, g: 255, b: 255,  # White text color
    z: ZIndex::METERS_LABEL  # Use same z-index as other meter labels for consistency
  }
end

# Renders the cannon sprite in the bottom right of the screen
# Cannon is used for shooting enemies in island encounters
# Positioned at bottom-right with padding from edges
# Args:
#   args - DragonRuby args object containing state and outputs
def render_cannon(args)
  args.outputs.primitives << args.state.cannon_sprite
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
