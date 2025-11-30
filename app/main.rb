$gtk.disable_nil_punning!

require 'app/gamestate.rb'
require 'app/navigation_system.rb'
require 'app/pathfinding_system.rb'
require 'app/meter_system.rb'
require 'app/tile_system.rb'
require 'app/wave_system.rb'
require 'app/input_handler.rb'
require 'app/auto_travel_system.rb'
require 'app/encounter_system/encounter_system.rb'
require 'app/renderer.rb'
require 'data/navigation_grid.rb'

def tick(args)
	init_state(args)
	init_auto_travel(args)

	unless args.state.game_over || args.state.victory
		# Handle encounter input first (can dismiss encounters)
		encounter_handled = handle_encounter_input(args)

		# Update auto-travel (moves ship automatically, triggers encounters)
		update_auto_travel(args)

		# Handle other input (tile placement, etc.) - only if no encounter active and wasn't just dismissed
		unless encounter_active?(args) || encounter_handled
			handle_input(args)
		end
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