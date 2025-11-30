# Auto-Travel System - Automatically moves ship left to right, stopping on each tile
#
# Core Concepts:
# - Ship automatically advances one slot at a time
# - Stops on each tile slot to trigger encounters
# - Waits for encounter to be dismissed before continuing
# - Travels from left to right (Caribbean -> European Port)
#
# Integration:
# - Called from main.rb each tick
# - Uses navigation_system.rb for ship movement
# - Uses encounter_system.rb to trigger encounters
# - Pauses when encounters are active

require 'app/navigation_system.rb'
require 'app/encounter_system/encounter_system.rb'

# Auto-travel configuration
AUTO_TRAVEL_ENABLED = true  # Set to false to disable auto-travel
TRAVEL_DELAY_TICKS = 30     # Frames to wait between slot movements (for visual pacing)

# Initialize auto-travel state
# Args:
#   args - DragonRuby args object containing state
def init_auto_travel(args)
  args.state.auto_travel_enabled ||= AUTO_TRAVEL_ENABLED
  args.state.auto_travel_next_move_at ||= Kernel.tick_count + TRAVEL_DELAY_TICKS
  args.state.auto_travel_paused ||= false
end

# Update auto-travel system - advances ship automatically
# Only moves if:
#   - Auto-travel is enabled
#   - No encounter is active
#   - Not paused
#   - Delay timer has elapsed
# Args:
#   args - DragonRuby args object containing state
def update_auto_travel(args)
  return unless args.state.auto_travel_enabled
  return if encounter_active?(args)  # Pause during encounters
  return if args.state.auto_travel_paused
  return if args.state.game_over || args.state.victory

  # Check if it's time to move
  return if Kernel.tick_count < args.state.auto_travel_next_move_at

  current_edge = get_current_edge(args.state)
  return unless current_edge

  # Check if we're at the end of the current edge
  if args.state.ship[:edge_progress] >= current_edge[:slots]
    # At end of edge - check for next edge (auto-choose leftmost/forward edge)
    next_edges = get_next_edge_choices(args.state)

    if next_edges.empty?
      # No more edges - journey complete or waiting for player
      args.state.auto_travel_paused = true
      return
    end

    # Auto-select the edge that goes most left-to-right (forward progress)
    # For outbound journey, choose edge with highest x coordinate destination (move right)
    # For return journey, choose edge with lowest x coordinate destination (move left)
    is_return = args.state.ship[:journey_phase] == :return
    best_edge = next_edges.send(is_return ? :min_by : :max_by) do |edge|
      dest_node = args.state.path_nodes[edge[:to]]
      dest_node ? dest_node[:position][:x] : 0
    end

    if best_edge
      advance_ship(args, best_edge[:id])

      # After transitioning to new edge, trigger encounter on first slot if it has a tile
      new_edge = get_current_edge(args.state)
      if new_edge && args.state.ship[:edge_progress] < new_edge[:slots]
        new_tile = new_edge[:tiles][args.state.ship[:edge_progress]]
        # Only trigger encounter if there's a tile in this slot (skip empty slots)
        if new_tile
          start_encounter(args, new_tile)
          args.state.auto_travel_paused = true
        end
      end

      args.state.auto_travel_next_move_at = Kernel.tick_count + TRAVEL_DELAY_TICKS
      return
    end
  end

  # Advance to next slot on current edge
  current_progress = args.state.ship[:edge_progress]
  next_slot_index = current_progress + 1

  # Get a fresh reference to the edge from state (not a cached reference)
  # This ensures we see the latest tile placements
  current_edge_from_state = get_edge(args.state, current_edge[:id])

  # Check if the next slot has a tile BEFORE advancing
  # This ensures we don't skip encounters due to edge completion logic
  next_tile = nil
  if next_slot_index < current_edge_from_state[:slots]
    next_tile = current_edge_from_state[:tiles][next_slot_index]
  end

  # Store the current edge ID before advancing (in case we transition to a new edge)
  current_edge_id = current_edge[:id]

  # Advance ship to next slot
  advance_ship(args)

  # After advancing, get a FRESH reference to the edge from state
  new_progress = args.state.ship[:edge_progress]
  new_edge = get_current_edge(args.state)

  # Get the actual edge from state.path_edges to ensure we have the latest data
  actual_edge = get_edge(args.state, new_edge[:id]) if new_edge

  # Determine which tile to check based on whether we're still on the same edge
  slot_tile = nil
  if actual_edge && actual_edge[:id] == current_edge_id
    # Still on the same edge - check the slot we just entered
    if new_progress < actual_edge[:slots]
      slot_tile = actual_edge[:tiles][new_progress]
    end
  elsif actual_edge
    # Transitioned to a new edge - check the first slot (index 0)
    if new_progress < actual_edge[:slots]
      slot_tile = actual_edge[:tiles][new_progress]
    end
  end

  # Only trigger encounter if there's a tile in this slot (skip empty slots)
  if slot_tile
    start_encounter(args, slot_tile)
    # Pause auto-travel until encounter is dismissed
    args.state.auto_travel_paused = true
  end

  # Set next move time
  args.state.auto_travel_next_move_at = Kernel.tick_count + TRAVEL_DELAY_TICKS
end

# Resume auto-travel after encounter is dismissed
# Called from encounter_system when encounter ends
# Args:
#   args - DragonRuby args object containing state
def resume_auto_travel(args)
  args.state.auto_travel_paused = false
  args.state.auto_travel_next_move_at = Kernel.tick_count + TRAVEL_DELAY_TICKS
end

