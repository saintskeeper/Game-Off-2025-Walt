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

	# Initialize graph structure (nodes and edges)
	args.state.graph ||= build_default_graph

	# Initialize ship position on graph (replaces ship_angle/ship_speed)
	# Find the first edge from the start node
	first_edge = PATH_EDGES.find { |e| e[:from] == :start }
	args.state.ship ||= {
		current_edge: first_edge ? first_edge[:id] : PATH_EDGES.first[:id],   # Which edge ship is on
		edge_progress: 0,                # Position along edge (0 to edge.slots-1)
		journey_phase: :outbound,        # :outbound or :return
		path_history: [:start]           # Visited nodes
	}

	args.state.hand ||= generate_hand # array of 3 tiles available to place
	args.state.game_over ||= false # false until game over
	args.state.victory ||= false # false until victory
	args.state.loop_count ||= 0 # tracks how many loops finished
	args.state.selected_tile ||= nil # which tile in hand is selected
end


