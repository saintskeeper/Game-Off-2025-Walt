# Navigation System - Ship movement along graph edges
#
# Core Concepts:
# - Ship moves from node to node along edges
# - Each edge has tile slots (variable count)
# - Ship position is edge_id + progress along that edge
# - Click-to-move: player advances ship one slot at a time
# - Branch points: player chooses which edge to take

require 'app/graph_system.rb'
require 'app/meter_system.rb'

# Advances ship forward one slot along current edge
# If target_edge_id provided, transitions to that edge (for branch choices)
# Triggers on_enter_slot() for slot with tile
# Handles edge completion and loop completion
# Args:
#   args - DragonRuby args object
#   target_edge_id - Optional: specific edge to transition to at branch point
def advance_ship(args, target_edge_id = nil)
  state = args.state
  current_edge = get_current_edge(state)

  # If target_edge specified, we're choosing a branch
  if target_edge_id
    # Transition to the chosen edge
    old_edge = current_edge ? current_edge[:id] : "nil"
    old_progress = state.ship[:edge_progress]

    # Update path history before changing edge (so we can still access old edge info)
    new_edge = get_edge(state, target_edge_id)
    if new_edge
      state.ship[:current_edge] = target_edge_id
      state.ship[:edge_progress] = 0
      state.ship[:path_history] << new_edge[:from] unless state.ship[:path_history].include?(new_edge[:from])

      puts "[DEBUG] ✅ TRANSITION SUCCESS:"
      puts "  - From: edge #{old_edge} (progress #{old_progress})"
      puts "  - To: edge #{target_edge_id} (progress 0)"
      puts "  - Route: #{new_edge[:from]} -> #{new_edge[:to]}"
      puts "  - Slots: #{new_edge[:slots]}"
      puts "  - Ship now on edge: #{state.ship[:current_edge]}, progress: #{state.ship[:edge_progress]}"

      # Check if we entered a slot with a tile
      tile = new_edge[:tiles][0]
      on_enter_slot(args, tile) if tile

      # Check for edge completion (should return early since progress = 0)
      check_edge_complete(args)

      # Verify the transition stuck
      verify_edge = get_current_edge(state)
      if verify_edge && verify_edge[:id] == target_edge_id
        puts "[DEBUG] ✅ Transition verified - ship is on correct edge"
      else
        puts "[ERROR] ❌ Transition failed - ship edge is #{verify_edge ? verify_edge[:id] : 'nil'}, expected #{target_edge_id}"
      end
    else
      puts "[ERROR] ❌ Could not find edge #{target_edge_id} after click!"
      puts "  - Available edges: #{state.path_edges.map { |e| e[:id] }.join(', ')}"
    end
    return
  end

  # Normal advancement along current edge
  state.ship[:edge_progress] += 1

  # Check if we entered a slot with a tile
  if state.ship[:edge_progress] < current_edge[:slots]
    tile = current_edge[:tiles][state.ship[:edge_progress]]
    on_enter_slot(args, tile) if tile
  end

  # Check for edge completion
  check_edge_complete(args)
end

# Called after advancing ship to handle edge transitions
# If reached end of edge:
#   - If destination is end node: trigger on_journey_complete() (victory)
#   - If only one outgoing edge: auto-advance to it
#   - If multiple outgoing edges: wait for player choice
# Args:
#   args - DragonRuby args object
def check_edge_complete(args)
  state = args.state
  current_edge = get_current_edge(state)
  return unless current_edge  # Safety check

  # Check if we've reached the end of the current edge
  # Only process if we're at or past the last slot
  return unless state.ship[:edge_progress] >= current_edge[:slots]

  puts "[DEBUG] check_edge_complete: edge=#{current_edge[:id]}, progress=#{state.ship[:edge_progress]}, slots=#{current_edge[:slots]}"

  # Get destination node
  dest_node_id = current_edge[:to]

  # Check if we've reached the European port (end node)
  # Don't automatically move - let player click to start return journey
  # The end node is stored in state during initialization
  end_node = state.end_node || :european_port
  if dest_node_id == end_node
    # Mark journey as complete and automatically start return journey
    state.journey_count ||= 0
    state.journey_count += 1
    state.ship[:journey_phase] = :return  # Mark as return journey phase
    puts "[JOURNEY] Reached European port (journey #{state.journey_count}), automatically starting return journey"

    # Find return edge and start moving
    outgoing_edges = get_outgoing_edges(state, dest_node_id)
    if outgoing_edges.length > 0
      new_edge = outgoing_edges.first
      state.ship[:current_edge] = new_edge[:id]
      state.ship[:edge_progress] = 0
      state.ship[:path_history] << dest_node_id unless state.ship[:path_history].include?(dest_node_id)

      # Check if we entered a slot with a tile
      tile = new_edge[:tiles][0]
      on_enter_slot(args, tile) if tile

      return
    else
      puts "[WARNING] Reached European port but found no return path!"
    end
  end

  # Check if we've reached the Caribbean port on return journey
  # If so, automatically start a new outbound journey
  start_node = state.start_node || :caribbean_port
  if dest_node_id == start_node && state.ship[:journey_phase] == :return
    # Completed return journey, start new outbound journey
    state.ship[:journey_phase] = :outbound
    state.ship[:path_history] = [start_node]

    # Find the first edge from Caribbean port (outbound)
    first_edge = get_outgoing_edges(state, start_node).find { |e| e[:to] != start_node }

    if first_edge
      state.ship[:current_edge] = first_edge[:id]
      state.ship[:edge_progress] = 0

      # Check if we entered a slot with a tile
      tile = first_edge[:tiles][0]
      on_enter_slot(args, tile) if tile

      puts "[JOURNEY] Returned to Caribbean port, starting new outbound journey"
      return
    end
  end

  # Get outgoing edges from destination node
  outgoing_edges = get_outgoing_edges(state, dest_node_id)

  # Special handling for European port: always wait for player click, even if only one return edge
  end_node = state.end_node || :european_port
  is_at_european_port = dest_node_id == end_node

  if outgoing_edges.length == 1 && !is_at_european_port
    # Only one option and not at European port - auto-advance
    state.ship[:current_edge] = outgoing_edges.first[:id]
    state.ship[:edge_progress] = 0
    state.ship[:path_history] << dest_node_id unless state.ship[:path_history].include?(dest_node_id)

    # Check if we entered a slot with a tile
    new_edge = outgoing_edges.first
    tile = new_edge[:tiles][0]
    on_enter_slot(args, tile) if tile

    # Recursively check if this new edge is also complete
    check_edge_complete(args)
  elsif outgoing_edges.length >= 1 && is_at_european_port
    # At European port - wait for player to click on return path
    # Ship stays at end of current edge
    # get_next_edge_choices will return the available return path options
    puts "[JOURNEY] At European port - waiting for player to click return path"
  elsif outgoing_edges.length > 1
    # Multiple options - wait for player to choose
    # Ship stays at end of current edge
    # get_next_edge_choices will return the available options
  else
    # No outgoing edges - check if we're at a special node
    end_node = state.end_node || :european_port
    if dest_node_id == end_node
      # At European port with no outgoing edges - this shouldn't happen with return paths
      # But if it does, mark journey complete and wait
      state.journey_count ||= 0
      state.journey_count += 1
      state.ship[:journey_phase] = :return
      puts "WARNING: Reached European port with no outgoing edges - return path may be missing"
    else
      puts "WARNING: Reached node #{dest_node_id} with no outgoing edges"
    end
  end
end

# Calculate ship's x,y screen position
# Interpolates along the pathfound route if available
# Falls back to linear interpolation if no path exists
# Args:
#   state - Game state object containing ship data
# Returns:
#   Hash with :x and :y keys for ship screen position
def ship_screen_position(state)
  current_edge = get_current_edge(state)

  # If edge has a pathfound route, use it
  if current_edge[:path] && current_edge[:path].length > 1
    require 'app/graph_system_dynamic.rb'
    return get_edge_path_position(current_edge, state.ship[:edge_progress])
  end

  # Fallback to linear interpolation
  from_node = state.path_nodes[current_edge[:from]]
  to_node = state.path_nodes[current_edge[:to]]

  # Calculate interpolation factor (0.0 to 1.0)
  progress = state.ship[:edge_progress].to_f / current_edge[:slots]

  # Linear interpolation between from and to node positions
  {
    x: from_node[:position][:x] + ((to_node[:position][:x] - from_node[:position][:x]) * progress),
    y: from_node[:position][:y] + ((to_node[:position][:y] - from_node[:position][:y]) * progress)
  }
end
