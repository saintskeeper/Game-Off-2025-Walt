# Encounter System - Handles encounter popups and interactions
#
# Core Concepts:
# - Encounters trigger when ship stops on a tile slot
# - Grey popup overlay displays during encounters
# - Player can interact with encounter popup to continue
# - Encounters pause auto-travel until resolved
#
# Integration:
# - Called from navigation_system.rb when ship enters a tile slot
# - Rendered in renderer.rb as overlay
# - Handles input in input_handler.rb or main.rb

# Encounter state management
# Args:
#   args - DragonRuby args object containing state
# Returns:
#   Boolean - true if an encounter is currently active
def encounter_active?(args)
  args.state.encounter_active == true
end

# Start an encounter when ship enters a tile slot
# This is called from navigation_system when ship moves to a slot with a tile
# Args:
#   args - DragonRuby args object containing state
#   tile - Tile hash that triggered the encounter (or nil for empty slot encounters)
def start_encounter(args, tile = nil)
  args.state.encounter_active = true
  args.state.encounter_tile = tile
  args.state.encounter_started_at = Kernel.tick_count

  puts "[ENCOUNTER] Started encounter on tile: #{tile ? tile[:type] : 'empty slot'}"
end

# End the current encounter and resume auto-travel
# Called when player clicks to dismiss the encounter popup
# Args:
#   args - DragonRuby args object containing state
def end_encounter(args)
  args.state.encounter_active = false
  args.state.encounter_tile = nil
  args.state.encounter_started_at = nil

  # Resume auto-travel after encounter ends
  begin
    require 'app/auto_travel_system.rb'
    resume_auto_travel(args)
  rescue LoadError
    # Auto-travel system not available, just continue
  end

  puts "[ENCOUNTER] Ended encounter, resuming travel"
end

# Render the encounter popup overlay
# Grey popup that covers the center of the screen
# Args:
#   args - DragonRuby args object containing state and outputs
def render_encounter_popup(args)
  return unless encounter_active?(args)

  # Grey popup box in center of the right panel
  popup_width = 400
  popup_height = 300
  # Center in right half (640 to 1280, center is 960)
  popup_x = 960 - (popup_width / 2)
  popup_y = (720 - popup_height) / 2

  # Popup sprite background
  args.outputs.primitives << {
    x: popup_x,
    y: popup_y,
    w: popup_width,
    h: popup_height,
    path: 'sprites/hud/encounter-hud/hud-encounter.png',
    z: 401
  }

  # Encounter text
  tile = args.state.encounter_tile
  encounter_text = tile ? "Encounter: #{tile[:type].to_s.upcase}" : "Encounter!"

  args.outputs.primitives << {
    x: popup_x + popup_width / 2,
    y: popup_y + popup_height - 50,
    text: encounter_text,
    size_px: 24,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 255,
    g: 255,
    b: 255,
    z: 403
  }

  # Instruction text
  args.outputs.primitives << {
    x: popup_x + popup_width / 2,
    y: popup_y + 50,
    text: "Click to continue",
    size_px: 18,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 200,
    g: 200,
    b: 200,
    z: 403
  }
end

# Handle input for encounter popup
# Returns true if encounter was dismissed, false otherwise
# Args:
#   args - DragonRuby args object containing state and inputs
# Returns:
#   Boolean - true if encounter was dismissed
def handle_encounter_input(args)
  return false unless encounter_active?(args)

  # If player clicks anywhere, dismiss the encounter
  if args.inputs.mouse.click
    end_encounter(args)
    return true
  end

  false
end

