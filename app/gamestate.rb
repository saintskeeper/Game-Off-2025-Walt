# Game State - Initializes and manages game state
#
# Core Concepts:
# - DragonRuby uses args.state to persist data between ticks
# - ||= operator initializes values only once (first tick)
# - All game data lives in state - think of it as your "database"

# Require graph_system for build_default_graph function
require 'app/graph_system.rb'
# Require tile_system for generate_hand function
require 'app/tile_system.rb'

def init_state(args)
	args.state.tick_count ||= 0 # frame counter for animations
	args.state.hold ||= 100 # starts at 100, game over at 0
	args.state.wind ||= 0 # starts at zero, victory at 100

	# Initialize graph data once from cache (survives hot reload)
	# This prevents constant reassignment warnings and graph regeneration flickering
	unless args.state.graph_initialized
		args.state.path_nodes = $dynamic_graph_cache[:nodes]
		args.state.path_edges = $dynamic_graph_cache[:edges]
		args.state.start_node = $dynamic_graph_cache[:start_node] || :caribbean_port
		args.state.end_node = $dynamic_graph_cache[:end_node] || :european_port
		args.state.graph_initialized = true
	end

	# Initialize graph structure (nodes and edges)
	args.state.graph ||= {
		nodes: args.state.path_nodes,
		edges: args.state.path_edges,
		start_node: args.state.start_node,
		end_node: args.state.end_node
	}

	# Initialize ship position on graph (replaces ship_angle/ship_speed)
	# Start at Caribbean port (leftmost node) - beginning of rum runner journey
	start_node_id = args.state.start_node || :caribbean_port
	first_edge = args.state.path_edges.find { |e| e[:from] == start_node_id }
	args.state.ship ||= {
		current_edge: first_edge ? first_edge[:id] : args.state.path_edges.first[:id],   # Which edge ship is on
		edge_progress: 0,                # Position along edge (0 to edge.slots-1)
		journey_phase: :outbound,        # :outbound (Caribbean to EU)
		path_history: [start_node_id]    # Visited nodes - starts at Caribbean port
	}

	args.state.hand ||= generate_hand # array of 3 tiles available to place
	args.state.game_over ||= false # false until game over
	args.state.victory ||= false # false until victory
	args.state.loop_count ||= 0 # tracks how many loops finished
	args.state.journey_count ||= 0 # tracks how many journeys completed (Caribbean to Europe)
	args.state.selected_tile ||= nil # which tile in hand is selected

	# Auto-populate some tiles on edges for testing encounters
	# This ensures there are tiles to trigger encounters during auto-travel
	unless args.state.tiles_auto_populated
		args.state.path_edges.each do |edge|
			# Place a tile on every 3rd slot (sparse placement for variety)
			edge[:slots].times do |i|
				if i % 3 == 0 && i > 0 && i < edge[:slots] - 1
					# Place a random tile type on this slot
					edge[:tiles][i] = { type: TILE_TYPES.sample }
				end
			end
		end
		args.state.tiles_auto_populated = true
		puts "[GAMESTATE] Auto-populated tiles on edges for testing"
	end

	# Pre-cache sprite definitions for performance
	# These are created once and reused every frame
	# Ship sprite is 64x64 at normal size
	args.state.ship_sprite_base ||= {
		w: 64,
		h: 64,
		path: 'sprites/hud/ships/base-ship.png',
		z: 100  # ZIndex::SHIP
	}

	# Hull Integrity meter uses ship-health sprite
	# Sprite is 256x128 at native size
	# Positioned on left side at top of screen, aligned with cargo meter level
	# Position sprite at top of screen to match cargo meter's top position
	screen_height = 720
	sprite_width = 256   # Native sprite width
	sprite_height = 128  # Native sprite height
	padding = 10
	# Position sprite at top-left: top edge near screen top
	# y position = screen_height - sprite_height - padding
	args.state.hold_meter_bg ||= {
		x: padding,  # Small padding from left edge
		y: screen_height - sprite_height - padding,  # Top of screen minus sprite height minus padding
		w: sprite_width,  # Native 256px width
		h: sprite_height,  # Native 128px height
		path: 'sprites/hud/ship-health/ship-health.png',
		z: 200  # High z-index to ensure it's above all map elements
	}

	# Cargo meter uses cargo-hud sprite
	# Sprite is 256x128 at native size
	# Positioned on right side at top of screen, aligned with hull integrity meter level
	# Position sprite at top of screen to match hull integrity meter's top position
	cargo_sprite_width = 256   # Native sprite width
	cargo_sprite_height = 128  # Native sprite height
	cargo_padding = 10
	args.state.wind_meter_bg ||= {
		x: 1280 - cargo_sprite_width - cargo_padding,  # Right side with padding
		y: screen_height - cargo_sprite_height - cargo_padding,  # Top of screen minus sprite height minus padding
		w: cargo_sprite_width,  # Native 256px width
		h: cargo_sprite_height,  # Native 128px height
		path: 'sprites/hud/cargo-hud/cargo-hud.png',
		z: 200  # High z-index to ensure it's above all map elements
	}
end


