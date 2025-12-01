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
	first_edge = args.state.path_edges&.find { |e| e[:from] == start_node_id }
	# Handle case where no edges exist (pathfinding failed or graph not initialized)
	# Default to nil current_edge if no edges available - will need to be handled by game logic
	current_edge_id = if first_edge
		first_edge[:id]
	elsif args.state.path_edges&.any?
		args.state.path_edges.first[:id]
	else
		nil  # No edges available - graph may not be fully initialized
	end

	args.state.ship ||= {
		current_edge: current_edge_id,   # Which edge ship is on (nil if no edges)
		edge_progress: 0,                # Position along edge (0 to edge.slots-1)
		journey_phase: :outbound,        # :outbound (Caribbean to EU)
		path_history: [start_node_id]    # Visited nodes - starts at Caribbean port
	}

	args.state.hand ||= generate_hand # array of 3 tiles available to place
	args.state.cargo_hold ||= Array.new(4, nil) # 4 cargo slots for items found on islands
	args.state.visited_islands ||= [] # tracks which islands have been visited this journey
	args.state.game_over ||= false # false until game over
	args.state.victory ||= false # false until victory
	args.state.loop_count ||= 0 # tracks how many loops finished
	args.state.journey_count ||= 0 # tracks how many journeys completed (Caribbean to Europe)
	args.state.selected_tile ||= nil # which tile in hand is selected

	# Auto-populate some tiles on edges for encounters
	# Limit: 4 pre-placed island tiles (player can place 4 more from hand = 8 total max)
	# Only populate if edges exist (graph must be initialized with valid paths)
	unless args.state.tiles_auto_populated
		if args.state.path_edges && args.state.path_edges.any?
			# Collect all valid slot positions (not first or last slot of any edge)
			valid_slots = []
			args.state.path_edges.each do |edge|
				(1...(edge[:slots] - 1)).each do |i|
					valid_slots << { edge: edge, slot: i }
				end
			end

			# Shuffle and take only 4 slots for pre-placed tiles
			max_preplace_tiles = 4
			slots_to_fill = valid_slots.shuffle.take(max_preplace_tiles)

			slots_to_fill.each do |slot_info|
				slot_info[:edge][:tiles][slot_info[:slot]] = { type: TILE_TYPES.sample }
			end

			args.state.tiles_auto_populated = true
			puts "[GAMESTATE] Auto-populated #{slots_to_fill.length} tiles on edges (max #{max_preplace_tiles})"
		else
			# Only warn once, then mark as populated to prevent spam
			unless args.state.graph_warning_shown
				puts "[GAMESTATE] WARNING: No edges available to populate tiles. Graph may not be initialized."
				puts "[GAMESTATE] Nodes: #{args.state.path_nodes&.keys || 'nil'} (#{args.state.path_nodes&.length || 0} total)"
				puts "[GAMESTATE] Edges: #{args.state.path_edges&.length || 0}"
				puts "[GAMESTATE] Graph cache nodes: #{$dynamic_graph_cache&.dig(:nodes)&.keys || 'nil'} (#{$dynamic_graph_cache&.dig(:nodes)&.length || 0} total)"
				puts "[GAMESTATE] Graph cache edges: #{$dynamic_graph_cache&.dig(:edges)&.length || 0}"
				args.state.graph_warning_shown = true
			end
			args.state.tiles_auto_populated = true  # Mark as done to prevent repeated warnings
		end
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

	# Cannon sprite for shooting enemies in island encounters
	# Sprite is positioned at bottom-right of screen
	# Size matches hand tiles (80x80) for visual consistency
	cannon_size = 80   # Match hand tile size for consistency
	cannon_padding = 10
	screen_width = 1280
	args.state.cannon_sprite ||= {
		x: screen_width - cannon_size - cannon_padding,  # Right side with padding
		y: cannon_padding,  # Bottom of screen with padding
		w: cannon_size,
		h: cannon_size,
		path: 'sprites/hud/cannon/cannon-export.png',
		z: 123  # ZIndex::CANNON - above hand elements
	}
end


