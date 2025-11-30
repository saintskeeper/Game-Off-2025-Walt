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
	args.state.hold ||= 0 # starts at zero, game over at 100
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
	args.state.selected_tile ||= nil # which tile in hand is selected

	# Pre-cache sprite definitions for performance
	# These are created once and reused every frame
	args.state.ship_sprite_base ||= {
		w: 64,
		h: 64,
		path: 'sprites/hud/ships/base-ship.png',
		z: 100  # ZIndex::SHIP
	}

	# Meter backgrounds use path: :solid for primitives collection rendering
	args.state.hold_meter_bg ||= {
		x: 50,
		y: 650,
		w: 200,
		h: 30,
		r: 50,
		g: 50,
		b: 50,
		z: 110,  # ZIndex::METERS_BG
		path: :solid
	}

	args.state.wind_meter_bg ||= {
		x: 1030,
		y: 650,
		w: 200,
		h: 30,
		r: 50,
		g: 50,
		b: 50,
		z: 110,  # ZIndex::METERS_BG
		path: :solid
	}
end


