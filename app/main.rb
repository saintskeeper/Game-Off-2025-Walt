$gtk.disable_nil_punning!

require 'app/gamestate.rb'
require 'app/navigation_system.rb'
require 'app/pathfinding_system.rb'
require 'app/meter_system.rb'
require 'app/tile_system.rb'
require 'app/wave_system.rb'
require 'app/input_handler.rb'
require 'app/renderer.rb'
require 'data/navigation_grid.rb'

def tick(args)
	init_state(args)

	unless args.state.game_over || args.state.victory
		handle_input(args)
		# Ship movement is now event-driven via clicks (no update_ship needed)
	end

	render(args)

	# Restart logic: Press R to restart after game over or victory
	if (args.state.game_over || args.state.victory) && args.inputs.keyboard.key_down.r
		# Clear static rendering collections before state reset
		args.outputs.static_sprites.clear
		args.outputs.static_lines.clear
		# Clear all state to restart
		args.state = {}
	end
end