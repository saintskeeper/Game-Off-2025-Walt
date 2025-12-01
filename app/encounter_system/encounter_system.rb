# Encounter System - Handles encounter popups and interactions
#
# Core Concepts:
# - Tile encounters trigger when ship stops on a tile slot
# - Island encounters trigger when ship reaches an island node (battle events)
# - Grey popup overlay displays during encounters
# - Player can interact with encounter popup to continue
# - Encounters pause auto-travel until resolved
#
# Integration:
# - Called from auto_travel_system.rb when ship enters a tile slot or island
# - Rendered in renderer.rb as overlay
# - Handles input in input_handler.rb or main.rb

# Encounter types
ENCOUNTER_TYPE_TILE = :tile
ENCOUNTER_TYPE_ISLAND = :island

# Encounter state management
# Args:
#   args - DragonRuby args object containing state
# Returns:
#   Boolean - true if an encounter is currently active
def encounter_active?(args)
  args.state.encounter_active == true
end

# Start a tile encounter when ship enters a tile slot
# This is called from auto_travel_system when ship moves to a slot with a tile
# Args:
#   args - DragonRuby args object containing state
#   tile - Tile hash that triggered the encounter (or nil for empty slot encounters)
def start_encounter(args, tile = nil)
  args.state.encounter_active = true
  args.state.encounter_type = ENCOUNTER_TYPE_TILE
  args.state.encounter_tile = tile
  args.state.encounter_island = nil
  args.state.encounter_started_at = Kernel.tick_count

  puts "[ENCOUNTER] Started tile encounter: #{tile ? tile[:type] : 'empty slot'}"
end

# Start an island encounter (battle) when ship reaches an island node
# This is called from auto_travel_system when ship reaches an island
# Args:
#   args - DragonRuby args object containing state
#   island_id - Symbol identifying the island node
def start_island_encounter(args, island_id)
  island = args.state.path_nodes[island_id]
  return unless island

  args.state.encounter_active = true
  args.state.encounter_type = ENCOUNTER_TYPE_ISLAND
  args.state.encounter_tile = nil
  args.state.encounter_island = island_id
  args.state.encounter_started_at = Kernel.tick_count

  # Island encounters may reward cargo items on the return journey
  args.state.encounter_reward = nil
  if args.state.ship[:journey_phase] == :return
    # Generate a random reward for the return journey
    args.state.encounter_reward = generate_island_reward(args)
  end

  island_name = island[:metadata][:name] || island_id.to_s
  puts "[ENCOUNTER] Started island encounter at: #{island_name}"
end

# Generate a random reward for island encounters on the return journey
# Args:
#   args - DragonRuby args object containing state
# Returns:
#   Hash with reward type and value
def generate_island_reward(args)
  reward_types = [:cargo_rum, :cargo_spices, :cargo_gold, :cargo_tobacco]
  {
    type: reward_types.sample,
    value: 10 + rand(16)  # Random value between 10-25 (mRuby doesn't support Range)
  }
end

# End the current encounter and resume auto-travel
# Called when player clicks to dismiss the encounter popup
# For island encounters on return journey, awards cargo if space available
# Args:
#   args - DragonRuby args object containing state
def end_encounter(args)
  # Handle island encounter rewards on return journey
  if args.state.encounter_type == ENCOUNTER_TYPE_ISLAND && args.state.encounter_reward
    # Try to add reward to cargo hold
    add_cargo_reward(args, args.state.encounter_reward)
  end

  args.state.encounter_active = false
  args.state.encounter_type = nil
  args.state.encounter_tile = nil
  args.state.encounter_island = nil
  args.state.encounter_started_at = nil
  args.state.encounter_reward = nil

  # Resume auto-travel after encounter ends
  begin
    require 'app/auto_travel_system.rb'
    resume_auto_travel(args)
  rescue
    # Auto-travel system not available, just continue
  end

  puts "[ENCOUNTER] Ended encounter, resuming travel"
end

# Add a cargo reward to the ship's cargo hold
# Only adds if there's an empty cargo slot
# Args:
#   args - DragonRuby args object containing state
#   reward - Hash with :type and :value keys
def add_cargo_reward(args, reward)
  # Initialize cargo hold if it doesn't exist (4 slots)
  args.state.cargo_hold ||= Array.new(4, nil)

  # Find first empty cargo slot
  empty_slot = args.state.cargo_hold.index(nil)

  if empty_slot
    args.state.cargo_hold[empty_slot] = reward
    puts "[CARGO] Added #{reward[:type]} (value: #{reward[:value]}) to cargo slot #{empty_slot}"
  else
    puts "[CARGO] Cargo hold full! Could not add #{reward[:type]}"
  end
end

# Render the encounter popup overlay
# Different content for tile vs island encounters
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

  # Determine encounter content based on type
  if args.state.encounter_type == ENCOUNTER_TYPE_ISLAND
    render_island_encounter_content(args, popup_x, popup_y, popup_width, popup_height)
  else
    render_tile_encounter_content(args, popup_x, popup_y, popup_width, popup_height)
  end

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

# Render content for tile encounters
def render_tile_encounter_content(args, popup_x, popup_y, popup_width, popup_height)
  tile = args.state.encounter_tile
  encounter_text = tile ? "Encounter: #{tile[:type].to_s.gsub('_', ' ').upcase}" : "Encounter!"

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
end

# Render content for island encounters (battle events)
def render_island_encounter_content(args, popup_x, popup_y, popup_width, popup_height)
  island_id = args.state.encounter_island
  island = args.state.path_nodes[island_id]
  island_name = island ? (island[:metadata][:name] || island_id.to_s) : "Unknown Island"

  # Title
  args.outputs.primitives << {
    x: popup_x + popup_width / 2,
    y: popup_y + popup_height - 50,
    text: island_name,
    size_px: 28,
    anchor_x: 0.5,
    anchor_y: 0.5,
    r: 255,
    g: 220,
    b: 100,
    z: 403
  }

  # Battle/encounter description
  is_return = args.state.ship[:journey_phase] == :return
  if is_return && args.state.encounter_reward
    reward = args.state.encounter_reward
    reward_name = reward[:type].to_s.gsub('cargo_', '').upcase

    args.outputs.primitives << {
      x: popup_x + popup_width / 2,
      y: popup_y + popup_height / 2 + 20,
      text: "Victory! You found treasure!",
      size_px: 20,
      anchor_x: 0.5,
      anchor_y: 0.5,
      r: 100,
      g: 255,
      b: 100,
      z: 403
    }

    args.outputs.primitives << {
      x: popup_x + popup_width / 2,
      y: popup_y + popup_height / 2 - 20,
      text: "+#{reward[:value]} #{reward_name}",
      size_px: 22,
      anchor_x: 0.5,
      anchor_y: 0.5,
      r: 255,
      g: 215,
      b: 0,
      z: 403
    }
  else
    args.outputs.primitives << {
      x: popup_x + popup_width / 2,
      y: popup_y + popup_height / 2,
      text: "Battle won!",
      size_px: 20,
      anchor_x: 0.5,
      anchor_y: 0.5,
      r: 255,
      g: 255,
      b: 255,
      z: 403
    }
  end
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

