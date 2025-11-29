require 'app/gamestate.rb'
require 'app/loop_system.rb'
require 'app/meter_system.rb'
require 'app/tile_system.rb'
require 'app/wave_system.rb'
require 'app/input_handler.rb'
require 'app/renderer.rb'

def tick(args)
	init_state(args)

	unless args.state.game_over || args.state.victory
		handle_input(args)
		update_ship(args)
	end

	render(args)

	# Restart logic: Press R to restart after game over or victory
	if (args.state.game_over || args.state.victory) && args.inputs.keyboard.key_down.r
		args.state = {}  # Clear all state to restart
	end
end