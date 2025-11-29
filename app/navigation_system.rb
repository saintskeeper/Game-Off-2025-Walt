# Navigation System - Ship movement along graph edges
#
# Core Concepts:
# - Ship moves from node to node along edges
# - Each edge has tile slots (variable count)
# - Ship position is edge_id + progress along that edge
# - Click-to-move: player advances ship one slot at a time
# - Branch points: player chooses which edge to take

require 'app/graph_system.rb'

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
    state.ship[:current_edge] = target_edge_id
    state.ship[:edge_progress] = 0

    # Update path history
    new_edge = get_edge(target_edge_id)
    state.ship[:path_history] << new_edge[:from] unless state.ship[:path_history].include?(new_edge[:from])

    # Check if we entered a slot with a tile
    tile = new_edge[:tiles][0]
    on_enter_slot(args, tile) if tile

    # Check for edge completion
    check_edge_complete(args)
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
#   - If destination is start node: trigger on_loop_complete()
#   - If only one outgoing edge: auto-advance to it
#   - If multiple outgoing edges: wait for player choice
# Args:
#   args - DragonRuby args object
def check_edge_complete(args)
  state = args.state
  current_edge = get_current_edge(state)

  # Check if we've reached the end of the current edge
  return unless state.ship[:edge_progress] >= current_edge[:slots]

  # Get destination node
  dest_node_id = current_edge[:to]

  # Check if we've returned to start (loop complete)
  if dest_node_id == :start
    on_loop_complete(args)

    # Reset to beginning
    state.ship[:current_edge] = :start_to_fork
    state.ship[:edge_progress] = 0
    state.ship[:path_history] = [:start]
    return
  end

  # Get outgoing edges from destination node
  outgoing_edges = get_outgoing_edges(dest_node_id)

  if outgoing_edges.length == 1
    # Only one option - auto-advance
    state.ship[:current_edge] = outgoing_edges.first[:id]
    state.ship[:edge_progress] = 0
    state.ship[:path_history] << dest_node_id

    # Check if we entered a slot with a tile
    new_edge = outgoing_edges.first
    tile = new_edge[:tiles][0]
    on_enter_slot(args, tile) if tile

    # Recursively check if this new edge is also complete
    check_edge_complete(args)
  elsif outgoing_edges.length > 1
    # Multiple options - wait for player to choose
    # Ship stays at end of current edge
    # get_next_edge_choices will return the available options
  else
    # No outgoing edges - shouldn't happen in a valid graph
    puts "WARNING: Reached node #{dest_node_id} with no outgoing edges"
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
  from_node = PATH_NODES[current_edge[:from]]
  to_node = PATH_NODES[current_edge[:to]]

  # Calculate interpolation factor (0.0 to 1.0)
  progress = state.ship[:edge_progress].to_f / current_edge[:slots]

  # Linear interpolation between from and to node positions
  {
    x: from_node[:position][:x] + ((to_node[:position][:x] - from_node[:position][:x]) * progress),
    y: from_node[:position][:y] + ((to_node[:position][:y] - from_node[:position][:y]) * progress)
  }
end
