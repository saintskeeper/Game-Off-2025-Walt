# Game State - Initializes and manages game state
#
# Core Concepts:
# - DragonRuby uses args.state to persist data between ticks
# - ||= operator initializes values only once (first tick)
# - All game data lives in state - think of it as your "database"

# Require tile_system for generate_hand function
require 'app/tile_system.rb'

def init_state(args)
	args.state.hold ||= 0 # starts at zero, game over at 100
	args.state.wind ||= 0 # starts at zero, victory at 100
	args.state.loop_slots ||= Array.new(12) { nil } # 12 positions, nil = empty, hash = tile
	args.state.ship_angle ||= 0 # radians, position on circle
	args.state.ship_speed ||= 0.02 # radians per tick
	args.state.hand ||= generate_hand # array of 3 tiles available to place
	args.state.game_over ||= false # false until game over
	args.state.victory ||= false # false until victory
	args.state.loop_count ||= 0 # tracks how many loops finished
	args.state.selected_tile ||= nil # which tile in hand is selected
end


